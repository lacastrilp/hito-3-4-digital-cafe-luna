#!/bin/bash
# ==============================================================================
# Digital Cafe Luna - Bootstrap de las EC2 del Auto Scaling Group
# Plantilla renderizada por Terraform (templatefile) desde compute.tf.
# Variables inyectadas: region, bucket, state_key, catalog_key, queue_url,
# wait_seconds, db_host, db_port, log_group_name, app_port
# ==============================================================================
set -euxo pipefail
exec > >(tee -a /var/log/dcl-bootstrap.log) 2>&1

# 1. Paquetes: Docker (portabilidad RNF-5) + CloudWatch Agent
dnf install -y docker amazon-cloudwatch-agent
systemctl enable --now docker

mkdir -p /opt/dcl/app /opt/dcl/data /var/log/dcl
touch /var/log/dcl/app.log
chmod 666 /var/log/dcl/app.log

# 2. Identidad de la instancia via IMDSv2 (token obligatorio)
TOKEN=$(curl -sS -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" http://169.254.169.254/latest/api/token)
INSTANCE_ID=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
BOOT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 3. Estado persistente y catalogo desde S3 (via NAT Gateway + IAM Role)
aws s3 cp "s3://${bucket}/${state_key}" /opt/dcl/data/dcl-state.json --region ${region} \
  || echo '{"error":"s3_state_unavailable"}' > /opt/dcl/data/dcl-state.json
aws s3 cp "s3://${bucket}/${catalog_key}" /opt/dcl/data/products.json --region ${region} \
  || echo '{"products":[]}' > /opt/dcl/data/products.json

# 4. Configuracion de la aplicacion (sin credenciales: boto3 usa el IAM Role)
cat > /opt/dcl/app/dcl.env <<ENV
AWS_REGION=${region}
AWS_DEFAULT_REGION=${region}
QUEUE_URL=${queue_url}
WAIT_SECONDS=${wait_seconds}
DB_HOST=${db_host}
DB_PORT=${db_port}
APP_PORT=${app_port}
INSTANCE_ID=$INSTANCE_ID
AZ=$AZ
BOOT_TIME=$BOOT_TIME
ENV

# 5. API web: /, /health, /catalog, /db-check, /simulate-error, POST /checkout
cat > /opt/dcl/app/app.py <<'PYAPP'
import json, os, socket, uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import boto3

LOG = "/var/log/dcl/app.log"
QUEUE_URL = os.environ["QUEUE_URL"]
DB_HOST = os.environ["DB_HOST"]
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
PORT = int(os.environ.get("APP_PORT", "8080"))
NODE = {"instance_id": os.environ.get("INSTANCE_ID"), "az": os.environ.get("AZ"), "boot_time": os.environ.get("BOOT_TIME")}
sqs = boto3.client("sqs")

def log(level, path, status, message):
    ts = datetime.now(timezone.utc).isoformat()
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"{ts} {level} path={path} status={status} instance={NODE['instance_id']} message={message}\n")

def read_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as exc:
        return {"error": str(exc)}

def db_reachable():
    try:
        with socket.create_connection((DB_HOST, DB_PORT), timeout=3):
            return True
    except OSError:
        return False

class Handler(BaseHTTPRequestHandler):
    def _send(self, status, payload, level="INFO", message="request_ok", quiet=False):
        if not quiet:
            log(level, self.path, status, message)
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            # Sin log: lo consultan el ALB y Route 53 cada pocos segundos
            self._send(200, {"status": "ok", "node": NODE}, quiet=True)
        elif self.path == "/":
            self._send(200, {"service": "Digital Cafe Luna", "node": NODE, "s3_state": read_json("/data/dcl-state.json")})
        elif self.path == "/catalog":
            self._send(200, read_json("/data/products.json"))
        elif self.path == "/db-check":
            ok = db_reachable()
            self._send(200 if ok else 503, {"rds_host": DB_HOST, "port": DB_PORT, "reachable": ok},
                       "INFO" if ok else "ERROR", "db_reachable" if ok else "db_unreachable")
        elif self.path == "/simulate-error":
            self._send(500, {"error": "controlled_failure"}, "ERROR", "controlled_failure")
        else:
            self._send(404, {"error": "not_found"}, "INFO", "not_found")

    def do_POST(self):
        if self.path != "/checkout":
            self._send(404, {"error": "not_found"}, "INFO", "not_found")
            return
        order_id = "DCL-" + uuid.uuid4().hex[:8].upper()
        event = {"orderId": order_id, "type": "ORDER_CREATED",
                 "createdAt": datetime.now(timezone.utc).isoformat(), "node": NODE["instance_id"]}
        try:
            resp = sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(event))
            self._send(202, {"orderId": order_id, "messageId": resp["MessageId"], "status": "queued"},
                       "INFO", "order_queued orderId=" + order_id)
        except Exception as exc:
            self._send(503, {"error": "queue_unavailable"}, "ERROR", "order_queue_failed " + type(exc).__name__)

    def log_message(self, *args):
        return

ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
PYAPP

# 6. Worker consumidor de la cola SQS (procesamiento asincrono de pedidos)
cat > /opt/dcl/app/worker.py <<'PYWORKER'
import json, os, time
from datetime import datetime, timezone
import boto3

LOG = "/var/log/dcl/app.log"
QUEUE_URL = os.environ["QUEUE_URL"]
WAIT = int(os.environ.get("WAIT_SECONDS", "5"))
INSTANCE = os.environ.get("INSTANCE_ID")
sqs = boto3.client("sqs")

def log(level, message):
    ts = datetime.now(timezone.utc).isoformat()
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"{ts} {level} path=worker status=- instance={INSTANCE} message={message}\n")

while True:
    resp = sqs.receive_message(QueueUrl=QUEUE_URL, MaxNumberOfMessages=5, WaitTimeSeconds=WAIT,
                               AttributeNames=["ApproximateReceiveCount"])
    for msg in resp.get("Messages", []):
        body = json.loads(msg["Body"])
        count = msg.get("Attributes", {}).get("ApproximateReceiveCount", "?")
        if body.get("simulateFailure"):
            # No se borra: reaparece tras el VisibilityTimeout y tras N intentos va a la DLQ
            log("ERROR", f"order_failed orderId={body.get('orderId')} receiveCount={count}")
            continue
        time.sleep(1)  # Simula generacion de comprobante / notificacion
        sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=msg["ReceiptHandle"])
        log("INFO", f"order_processed orderId={body.get('orderId')} receiveCount={count}")
PYWORKER

# 7. Contenedores (imagen oficial desde ECR Public, sin limites de Docker Hub).
#    --network host: el contenedor usa IMDSv2 del host con hop limit = 1.
IMAGE=public.ecr.aws/docker/library/python:3.11-slim
for svc in web worker; do
  if [ "$svc" = "web" ]; then SCRIPT=app.py; else SCRIPT=worker.py; fi
  docker run -d --name "dcl-$svc" --restart unless-stopped --network host \
    --env-file /opt/dcl/app/dcl.env \
    -v /opt/dcl/app:/app:ro -v /opt/dcl/data:/data:ro -v /var/log/dcl:/var/log/dcl \
    "$IMAGE" sh -c "pip install --no-cache-dir --quiet boto3 && exec python /app/$SCRIPT"
done

# 8. CloudWatch Agent: /var/log/dcl/app.log -> Log Group (stream = instance_id)
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CW'
{
  "agent": { "run_as_user": "root" },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/dcl/app.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
CW

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
