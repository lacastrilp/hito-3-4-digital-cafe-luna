# DIGITAL CAFÉ LUNA — HITOS 3 Y 4: IMPLEMENTACIÓN Y PREPARACIÓN OPERATIVA
## ARTEFACTO DEL ESTUDIANTE · v01 (ENTREGABLE INTEGRADO S15)

---

| Campo | Detalle |
| :--- | :--- |
| **Asignatura** | Computación en Nube (2026-2) — Universidad EAFIT |
| **Evaluativo** | Hitos 3 y 4 — Implementación (5 %) y Preparación Operativa (5 %) |
| **Peso Total** | 10 % del proyecto (dentro del 25 % del proyecto base) |
| **Fecha de Entrega** | 20 de octubre de 2026 · Semana 15 (S15) |
| **Modalidad** | Equipos permanentes de 4 integrantes · **Grupo 1** |
| **Operación** | Entrega previa + verificación presencial focalizada |
| **Integrantes** | - **Paulina Velásquez Londoño**<br>- **Luis Alejandro Castrillón Pulgarín**<br>- **Martín Valencia Vallejo**<br>- **Alberto Cervantes Forero** |

---

## 1. ARQUITECTURA REALMENTE IMPLEMENTADA Y VERSIÓN DE LA SOLUCIÓN

### 1.1 Trazabilidad Evolutiva: Hito 1 → Hito 2 → Hitos 3 y 4
La solución implementada por el **Grupo 1** para **Digital Café Luna** materializa la evolución progresiva planteada desde la formulación del proyecto, sin crear una arquitectura desconectada desde cero:

1. **Punto de partida en Hito 1 (Definición y Alcance):**
   - **Problema original:** Operación del canal digital sobre un monolito tradicional con despliegues manuales, acoplamiento entre cómputo y datos, monitoreo nulo y falta de visibilidad de seguridad y costos.
   - **Requerimientos comprometidos:** Provisión automatizada (`RF-1`), desacoplamiento por mensajería (`RF-2`), almacenamiento centralizado de objetos (`RF-3`), separación entre cómputo y persistencia (`RF-4`), control de versiones en Git (`RF-5`), segmentación de red pública/privada (`RNF-1`), mínimo privilegio IAM (`RNF-2`), monitoreo y alarmas basadas en umbrales (`RNF-3`), etiquetado financiero y análisis de *cost drivers* (`RNF-4`), portabilidad basada en estándares Linux/contenedores (`RNF-5`) y cifrado en tránsito y reposo (`RNF-6`).
   - **Backlog priorizado:** Historias `B01` a `B12`.

2. **Diseño objetivo en Hito 2 (Arquitectura y Migración — Referencia más reciente):**
   - Se definió una arquitectura **IaaS en AWS (`us-east-1`)** de 3 capas con VPC segmentada, Application Load Balancer (ALB), Auto Scaling Group (ASG) de instancias EC2, persistencia relacional en Amazon RDS PostgreSQL Multi-AZ (Primary en AZ A + Standby síncrona en AZ B), almacenamiento de objetos e imágenes/estado en Amazon S3 (`RF-3`) y cola de mensajería Amazon SQS (`RF-2`), acompañada de un plan de migración progresiva en 5 etapas con punto de retorno (*rollback*) y convivencia híbrida estrictamente temporal.

3. **Versión realmente implementada y validada en Hitos 3 y 4 (Estado S15):**
   - Se implementó y validó funcionalmente en **AWS (`us-east-1`)** el núcleo operativo y arquitectónico del canal digital de Digital Café Luna sobre la VPC del proyecto (`dcl-dev-vpc` — `10.20.0.0/16`, `vpc-0cba829cb5c7746b2`), distribuyendo el tráfico mediante un **Application Load Balancer (`dcl-dev-alb`)** y un **Target Group (`dcl-dev-tg-web`)** hacia instancias **Amazon EC2 (`Amazon Linux 2023`, `t3.micro`)** gestionadas por un **Auto Scaling Group (`dcl-dev-asg-web`)** multi-zona (`us-east-1a` y `us-east-1b`) a partir del **Launch Template (`dcl-dev-lt-web`)** con **IMDSv2 obligatorio**.
   - Se implementó y verificó la **separación entre el cómputo efímero y la persistencia externa** (`RF-3`, `RF-4`) almacenando el estado persistente y activos del catálogo en el bucket privado **Amazon S3 (`dcl-dev-state-<account-id>-team-01`, objeto `state/dcl-state.json`)** con bloqueo total de acceso público y cifrado por defecto, complementado con el diseño de persistencia relacional en **RDS PostgreSQL**.
   - Se implementó y validó el **desacoplamiento asíncrono de pedidos (`RF-2`, `B04`)** mediante la cola **Amazon SQS Standard (`dcl-dev-orders-queue`)**, separando el componente productor de órdenes (`producer.py`) del procesador/consumidor (`consumer.py`) con manejo de *backlog*, `VisibilityTimeout=30s` y `WaitTimeSeconds=5s`.
   - Se integró la **capa de seguridad y observabilidad operativa (`RNF-2`, `RNF-3`, `B05`, `B06`)** mediante perfiles de instancia IAM de mínimo privilegio (cero *Access Keys* estáticas), ingesta centralizada de registros desde `/var/log/dcl/app.log` con `amazon-cloudwatch-agent` hacia el Log Group **`/dcl/dev/ops`** (retención de 7 días), filtro de métricas **`dcl-dev-error-filter` (`ErrorCount`)**, alarma **`dcl-dev-ops-alarm`** y panel **`dcl-dev-ops-dashboard`**.

---

### 1.2 Diagrama de la Arquitectura Realmente Desplegada

```text
                                 [ CLIENTES / OPERADORES DEL CANAL DIGITAL ]
                                                      │
                                                      ▼ (HTTP/80 · HTTPS/443)
+-------------------------------------------------------------------------------------------------------------+
|                                         AWS CLOUD — REGIÓN us-east-1                                        |
|                                                                                                             |
|  VPC: dcl-dev-vpc (10.20.0.0/16 · vpc-0cba829cb5c7746b2)                                                    |
|  +-------------------------------------------------------------------------------------------------------+  |
|  |                                 INTERNET GATEWAY (dcl-lab1-igw)                                       |  |
|  +-------------------------------------------------------------------------------------------------------+  |
|                                                     │                                                       |
|                    ┌────────────────────────────────┴────────────────────────────────┐                      |
|                    ▼ (0.0.0.0/0 -> IGW)                                              ▼ (0.0.0.0/0 -> IGW)   |
|  +-------------------------------------------------+   +-------------------------------------------------+  |
|  | AVAILABILITY ZONE A (us-east-1a)                |   | AVAILABILITY ZONE B (us-east-1b)                |  |
|  |                                                 |   |                                                 |  |
|  | [SUBNET PÚBLICA A] (10.20.10.0/24)              |   | [SUBNET PÚBLICA B] (10.20.20.0/24)              |  |
|  |  • Application Load Balancer: dcl-dev-alb       |   |  • Application Load Balancer: dcl-dev-alb       |  |
|  |  • Target Group: dcl-dev-tg-web (Health Check)  |   |  • Target Group: dcl-dev-tg-web (Health Check)  |  |
|  +-------------------------------------------------+   +-------------------------------------------------+  |
|                    │                                                                 │                      |
|                    ▼                                                                 ▼                      |
|  +-------------------------------------------------+   +-------------------------------------------------+  |
|  | [CAPA DE CÓMPUTO ELÁSTICO E INSTANCIAS EC2]     |   | [CAPA DE CÓMPUTO ELÁSTICO E INSTANCIAS EC2]     |  |
|  |  • Auto Scaling Group: dcl-dev-asg-web          |   |  • Auto Scaling Group: dcl-dev-asg-web          |  |
|  |    (Min: 2 | Desired: 2 | Max: 4)               |   |    (Min: 2 | Desired: 2 | Max: 4)               |  |
|  |  • Launch Template: dcl-dev-lt-web (IMDSv2)     |   |  • Launch Template: dcl-dev-lt-web (IMDSv2)     |  |
|  |  • Workload Web + Productor/Consumidor + CW Agt |   |  • Workload Web + Productor/Consumidor + CW Agt |  |
|  |                                                 |   |                                                 |  |
|  | [SUBNET PRIVADA A] (10.20.110.0/24)             |   | [SUBNET PRIVADA B] (10.20.120.0/24)             |  |
|  |  • Route Table: dcl-rt-private (Solo local)     |   |  • Route Table: dcl-rt-private (Solo local)     |  |
|  |  • NACL: dcl-nacl-private + SG: dcl-sg-private  |   |  • NACL: dcl-nacl-private + SG: dcl-sg-private  |  |
|  |  • Capa de Datos Aislada / RDS Primary          |   |  • Capa de Datos Aislada / RDS Standby          |  |
|  +-------------------------------------------------+   +-------------------------------------------------+  |
|                    │                                                                 │                      |
|                    └───────────────┬─────────────────────────────────┬───────────────┘                      |
|                                    │ (IAM Roles · Credenciales STS)  │                                      |
|                    ┌───────────────┴───────────────┬─────────────────┴───────────────┐                      |
|                    ▼                               ▼                                 ▼                      |
|  +---------------------------------+  +--------------------------------+  +------------------------------+  |
|  | PERSISTENCIA EXTERNA (RF-3/RF-4)|  | MENSAJERÍA ASÍNCRONA (RF-2)    |  | OBSERVABILIDAD (RNF-3 / B05) |  |
|  | • Amazon S3 Bucket Privado:     |  | • Amazon SQS Standard Queue:   |  | • CW Log Group: /dcl/dev/ops |  |
|  |   dcl-dev-state-<acct>-team-01  |  |   dcl-dev-orders-queue         |  |   (Retención: 7 días)        |  |
|  |   Objeto: state/dcl-state.json  |  |   VisibilityTimeout: 30s       |  | • Metric Filter: ErrorCount  |  |
|  |   Block Public Access + SSE-S3  |  |   WaitTimeSeconds: 5s          |  | • Alarma: dcl-dev-ops-alarm  |  |
|  | • Diseño RDS PostgreSQL MultiAZ |  | • Flujo: producer -> consumer  |  | • Dashboard: dcl-dev-ops-dash|  |
|  +---------------------------------+  +--------------------------------+  +------------------------------+  |
+-------------------------------------------------------------------------------------------------------------+
```

---

### 1.3 Inventario de Componentes Principales Efectivamente Utilizados

| Categoría | Recurso / Componente | Identificador / Configuración Real | Relación con Hito 1 y Hito 2 |
| :--- | :--- | :--- | :--- |
| **Red y Segmentación** | VPC Multi-AZ | `dcl-dev-vpc` (`10.20.0.0/16` · `vpc-0cba829cb5c7746b2`) en `us-east-1` | Cumple `RNF-1`, `B03` y Etapa 1 de Hito 2. |
| **Subredes y Ruteo** | 2 Públicas + 2 Privadas | Públicas: `10.20.10.0/24` (`1a`), `10.20.20.0/24` (`1b`) → `dcl-rt-public` (`0.0.0.0/0 -> IGW`).<br>Privadas: `10.20.110.0/24` (`1a`), `10.20.120.0/24` (`1b`) → `dcl-rt-private` (`10.20.0.0/16 -> local`). | Segmentación estricta por tablas de enrutamiento y NACLs (`dcl-nacl-private`). |
| **Balanceo de Carga** | Application Load Balancer | `dcl-dev-alb` (HTTP/80) + Target Group `dcl-dev-tg-web` | Cumple decisión `D1`/`D5` de Hito 2 (punto único de entrada DNS y *health checks*). |
| **Cómputo Elástico** | Auto Scaling Group & Launch Template | `dcl-dev-asg-web` (`Min=2, Desired=2, Max=4`) + `dcl-dev-lt-web` (`Amazon Linux 2023`, `t3.micro`, `IMDSv2=required`) | Cumple `RF-4`, `RNF-5` y decisión `D1` de Hito 2 (reemplazo automático de cómputo). |
| **Persistencia y Estado** | Amazon S3 Bucket Privado (+ modelo RDS) | `dcl-dev-state-<account-id>-team-01` (`state/dcl-state.json`, `BlockPublicAccess=true`, SSE-S3) | Cumple `RF-3`, `RF-4`, `RNF-6` y decisiones `D2`/`D3` de Hito 2 (estado fuera de EC2). |
| **Integración / Cola** | Amazon SQS Standard | `dcl-dev-orders-queue` (`VisibilityTimeout=30s`, `ReceiveMessageWaitTimeSeconds=5s`) + `producer.py` / `consumer.py` | Cumple `RF-2`, `B04` y decisión `D6` de Hito 2 (desacoplamiento asíncrono de pedidos). |
| **Identidades (IAM)** | IAM Roles & Instance Profiles | `dcl-dev-role-web` (`dcl-dev-policy-s3-state`), `dcl-dev-role-lab2-sqs`, `dcl-dev-role-lab3-ops` | Cumple `RNF-2` y decisión `D11` (mínimo privilegio por función y cero *Access Keys*). |
| **Seguridad de Red** | Security Groups | `dcl-dev-sg-web` / `dcl-dev-sg-lab3` (HTTP/80 sin SSH 22 para web), `dcl-sg-private` (solo origen SG autorizado) | Cumple `RNF-1`, `RNF-6` y mitigación de riesgo de bloqueo/exposición de Hito 2. |
| **Observabilidad** | CloudWatch Logs, Metric Filter, Alarm & Dashboard | Log Group `/dcl/dev/ops` (retención 7 días), filtro `dcl-dev-error-filter` (`ErrorCount`), alarma `dcl-dev-ops-alarm` (`Sum >= 1`/60s) y `dcl-dev-ops-dashboard` | Cumple `RNF-3`, `B05`, `B06` y decisión `D12` de Hito 2. |
| **Gobierno / FinOps** | Esquema de Etiquetas (Tags) | `dcl:project=digital-cafe-luna`, `dcl:environment=dev`, `dcl:owner-team=team-01`, `dcl:managed-by=console/terraform` | Cumple `RNF-4`, `B09` y decisión `D13` de Hito 2. |

---

## 2. HITO 3 — IMPLEMENTACIÓN, FLUJO FUNCIONAL, VALIDACIONES Y DIFERENCIAS FRENTE A HITO 2 (5 %)

### 2.1 Despliegue y Relación con el Diseño Revisado
El despliegue se ejecutó de forma incremental siguiendo la arquitectura revisada en el Hito 2 sobre la región `us-east-1`:
1. **Capa de Red (`dcl-dev-vpc`):** Se verificó la VPC `10.20.0.0/16` con sus 4 subredes distribuidas en `us-east-1a` y `us-east-1b`, comprobando que las subredes públicas enrutan `0.0.0.0/0` hacia `dcl-lab1-igw` y las subredes privadas mantienen exclusivamente la ruta local `10.20.0.0/16`, protegidas por la NACL `dcl-nacl-private` (Regla 100 Allow `10.20.0.0/16`) y el Security Group `dcl-sg-private` referenciando únicamente al Security Group de la capa superior.
2. **Capa de Balanceo y Cómputo Elástico (`dcl-dev-alb` + `dcl-dev-asg-web`):** Se configuró el Launch Template `dcl-dev-lt-web` con `User Data` automatizado que instala el servidor web, consulta metadatos de instancia (`Instance ID` y `Availability Zone`) usando token **IMDSv2**, registra el estado local efímero (`local-state.txt`) y recupera el estado persistente desde S3. El ASG mantiene `Desired = 2` instancias `InService` registradas como `healthy` en el Target Group `dcl-dev-tg-web`.
3. **Capa de Persistencia Desacoplada (`Amazon S3`):** Se aprovisionó el bucket privado `dcl-dev-state-<account-id>-team-01` con las 4 banderas de `PublicAccessBlock` activas (`true`) y el objeto `state/dcl-state.json`.
4. **Capa de Mensajería Asíncrona (`Amazon SQS`):** Se desplegó la cola `dcl-dev-orders-queue` consumida mediante `boto3` desde los procesos desacoplados `producer.py` y `consumer.py` autenticados con credenciales temporales de rol IAM.

---

### 2.2 Flujo Funcional de Extremo a Extremo (Validación Mínima Requerida)

Siguiendo la regla de validación funcional del Hito 3:

```text
[ Entrada / Acción ] ──▶ [ Procesamiento ] ──▶ [ Integración (SQS) ] ──▶ [ Persistencia / Resultado ] ──▶ [ Evidencia Observable ]
```

| Etapa del Flujo | Descripción Técnica en Digital Café Luna | Componente AWS Involucrado | Resultado y Evidencia Verificable |
| :--- | :--- | :--- | :--- |
| **1. Entrada / Acción** | El cliente o usuario del canal digital realiza una solicitud HTTP (`GET /`, `GET /health`) al DNS único del balanceador o dispara la creación de un pedido (`orderId=DCL-001` .. `DCL-004`). | **ALB (`dcl-dev-alb`)** + **Target Group (`dcl-dev-tg-web`)** | Petición recibida en puerto TCP/80 y enrutada exclusivamente a un target en estado `healthy` en `us-east-1a` o `us-east-1b`. |
| **2. Procesamiento** | La instancia EC2 activa procesa la solicitud, obtiene su identidad de cómputo vía **IMDSv2** (`PUT /latest/api/token`) y ejecuta la lógica de aplicación o el productor de pedidos (`producer.py`). | **EC2 (`dcl-dev-asg-web`)** + **IAM Role (`dcl-dev-role-web` / `sqs`)** | Generación de evento `ORDER_CREATED` con `timestamp` UTC e identificación del nodo (`Instance ID`, `AZ` y `boot_time`). |
| **3. Integración / Mensajería** | El productor publica de forma asíncrona el mensaje JSON del pedido en la cola mediante `sqs:SendMessage`. El consumidor independiente (`consumer.py`) realiza *long polling* (`WaitTimeSeconds=5`, `VisibilityTimeout=30`) con `sqs:ReceiveMessage`. | **Amazon SQS Standard (`dcl-dev-orders-queue`)** | Desacoplamiento temporal y lógico comprobado: `SENT orderId=DCL-001 MessageId=<id>` → `RECEIVED` → `PROCESSED` → `DELETED` (`sqs:DeleteMessage`). |
| **4. Persistencia / Resultado** | Las instancias EC2 recuperan el estado persistente del negocio desde el bucket S3 privado (`s3:GetObject` sobre `state/dcl-state.json`) sin almacenarlo como estado único en el disco local efímero de la EC2. | **Amazon S3 (`state/dcl-state.json`)** | Si una instancia EC2 muere y el ASG lanza una nueva, el estado local (`local-state.txt`) cambia, pero el estado persistente en S3 permanece 100 % intacto. |
| **5. Evidencia Observable** | El sistema devuelve HTTP 200 con el estado persistente renderizado, el *backlog* de SQS converge a `0` tras procesar los pedidos, y la telemetría se envía a CloudWatch Logs (`/dcl/dev/ops`). | **HTTP Response + AWS CLI + CloudWatch Logs** | Capturas `HTTPResponses.png`, `HappyPath/ProducerOn.png`, `HappyPath/ConsumerON.png` y registros `INFO status=200` en `/dcl/dev/ops`. |

---

### 2.3 Funcionamiento de la Integración y Mensajería Asíncrona (`RF-2`)

Para demostrar que el canal digital de Digital Café Luna no pierde pedidos cuando el componente de procesamiento secundario se detiene o experimenta fallas transitorias, se implementó y probó la cola **`dcl-dev-orders-queue`** con tres escenarios verificables:

1. **Escenario 1 — Happy Path (`DCL-001`):** Con `consumer.py` activo, `producer.py` envía el pedido `DCL-001`. El consumidor lo recibe inmediatamente (`receiveCount=1`), procesa la orden en 2 segundos y ejecuta `delete_message` usando el `ReceiptHandle`, dejando `ApproximateNumberOfMessages = 0`.
2. **Escenario 2 — Desacoplamiento Temporal y Absorción de Backlog (`DCL-002`, `DCL-003`, `DCL-004`):**
   - Se detuvo intencionalmente el proceso `consumer.py` (`Consumer = OFF`) manteniendo la instancia EC2 en `Running`.
   - El productor envió 3 pedidos consecutivos (`DCL-002`, `DCL-003`, `DCL-004`) sin sufrir bloqueo ni error (`Producer = OK`).
   - Se verificó mediante `aws sqs get-queue-attributes` que la cola acumuló un **backlog visible de `3` mensajes** (`ApproximateNumberOfMessages = 3`).
   - Al reactivar `consumer.py` (`Consumer = ON`), los tres pedidos pendientes fueron drenados, procesados y eliminados de la cola hasta regresar a **`Backlog = 0`**.
3. **Escenario 3 — Fallo Controlado, `VisibilityTimeout` y Reintento Automático (`DCL-FAIL-001`):**
   - Se envió un pedido con bandera de fallo (`python3.11 producer.py DCL-FAIL-001 --fail`).
   - El consumidor recibió el mensaje (`receiveCount=1`), detectó el fallo (`PROCESSING FAILED — message NOT deleted`) y omitió `DeleteMessage`.
   - Durante los **30 segundos de `VisibilityTimeout`**, el mensaje permaneció en estado `NotVisible` (*in-flight*). Al expirar los 30 segundos, el mismo `MessageId` reapareció automáticamente en la cola y fue reentregado al consumidor (`receiveCount=2`), demostrando la semántica *at-least-once* de SQS Standard.

---

### 2.4 Validaciones Ejecutadas y Resultados Observados

| ID | Prueba Ejecutada | Objetivo Técnico | Resultado Esperado | Resultado Observado y Evidencia Real | Estado |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **V-01** | **Aislamiento de Red, Tablas de Ruteo y Ping Privado** | Comprobar que las subredes privadas no tienen salida directa a IGW y solo aceptan tráfico desde el SG público autorizado (`RNF-1`). | SSH exitoso a instancia pública desde `My IP/32`. Ping ICMP hacia IP privada bloqueado sin regla SG y exitoso al autorizar `dcl-sg-public`. | `0% packet loss` tras autorizar SG origen; `100% packet loss` sin la regla. Subred privada verificada solo con ruta `10.20.0.0/16 -> local`. (`PingWithICMPSecurityGroup.jpeg`) | **APROBADO** |
| **V-02** | **Balanceo de Carga en ALB Multi-AZ** | Verificar que `dcl-dev-alb` distribuye peticiones HTTP entre instancias en `us-east-1a` y `us-east-1b` bajo un único DNS. | Respuestas HTTP 200 alternando el `Instance ID` y la `Availability Zone` de las instancias del Target Group `dcl-dev-tg-web`. | Peticiones sucesivas a `http://$ALB_DNS` respondieron desde ambos nodos saludables (`healthy`). (`ALBTable.png`, `HTTPResponses.png`, `Targets.png`) | **APROBADO** |
| **V-03** | **Resiliencia y Reemplazo Automático en ASG (`Prueba A: Reboot` vs `Prueba B: Terminate`)** | Demostrar la diferencia entre reinicio de SO y pérdida real de capacidad (`desired=2`) en `dcl-dev-asg-web`. | En `Terminate`, la capacidad cae temporalmente a `Running=1`; el ASG detecta `capacidad < desired` y lanza una nueva instancia `EC2-C` hasta restaurar `Desired=2`. | Al terminar `EC2-A`, el ASG aprovisionó automáticamente una nueva instancia, la registró en `dcl-dev-tg-web` como `healthy` y restableció los 2 nodos activos. (`ASGDuringProofB.jpeg`, `NewTargets.png`) | **APROBADO** |
| **V-04** | **Separación entre Cómputo y Estado Persistente en S3 (`RF-3`, `RF-4`)** | Confirmar que al destruir una instancia EC2 del ASG, la nueva instancia conserva el acceso al estado persistente en S3. | `Instance ID`, `Boot time` y `local-state.txt` cambian en la instancia de reemplazo; `state/dcl-state.json` en S3 permanece idéntico. | La nueva instancia EC2 asumió `dcl-dev-role-web` vía IMDSv2, leyó `s3://.../state/dcl-state.json` y sirvió exactamente el mismo JSON (`version: 1`) con nuevo `Instance ID`. | **APROBADO** |
| **V-05** | **Desacoplamiento Asíncrono y Reintentos en SQS (`RF-2`)** | Validar `Happy Path`, acumulación de *backlog* con consumidor apagado y reintento tras `VisibilityTimeout=30s`. | `DCL-001` procesado y borrado; `DCL-002..004` retenidos en cola (`Backlog=3`) con consumidor apagado y drenados al reactivar (`Backlog=0`); `DCL-FAIL-001` reentregado tras 30s. | Secuencia completa comprobada por CLI y terminales A/B con trazabilidad exacta de `MessageId` y `ApproximateReceiveCount`. (`ConsumerOFFProducerON3Messages.png`, `ReactivarConsumerSeProcesaCola.png`) | **APROBADO** |

---

### 2.5 Diseño vs. Implementación (Cambios respecto a Hito 2 y Justificación)

| Elemento | Diseñado en Hito 2 (`cn-2026-2-hito-02...pdf`) | Realmente Implementado en Hitos 3 y 4 | Justificación Técnica y de Costos (Trade-off) |
| :--- | :--- | :--- | :--- |
| **Direccionamiento VPC y Uso de NAT Gateways** | VPC `10.0.0.0/16` con 2 NAT Gateways activos (uno en cada AZ) y 6 subredes (públicas, cómputo privado y datos). | VPC `dcl-dev-vpc` (`10.20.0.0/16`, `vpc-0cba829cb5c7746b2`) con 4 subredes Multi-AZ (`10.20.10.0/24`, `10.20.20.0/24`, `10.20.110.0/24`, `10.20.120.0/24`) **sin NAT Gateways permanentes**. | En el Hito 2 se identificó como riesgo medio el sobrecosto por NAT Gateways activos ($0.045/h por AZ + datos). En la implementación real se eliminaron los NAT Gateways continuos en el entorno `dev` para proteger el presupuesto del equipo, demostrando igualmente el aislamiento de subredes privadas mediante `dcl-rt-private` y `dcl-nacl-private`. |
| **Demostración de Persistencia Desacoplada (`RF-3` / `RF-4`)** | Persistencia dual con **Amazon RDS PostgreSQL Multi-AZ** + **Amazon S3 Bucket**. | Validación práctica del estado persistente compartido sobre **Amazon S3 Privado (`state/dcl-state.json`)** consumido por el ASG EC2 mediante IAM Role, manteniendo la arquitectura lista para RDS. | Permite verificar de forma determinista y sin costo continuo de instancias `db.t3.micro` Multi-AZ que al terminar una instancia EC2 (`Terminate`), el cómputo cambia (`Instance ID` y `boot_time` nuevos) mientras el estado externo sobrevive intacto en S3. |
| **Acceso a Metadatos de Instancia (IMDS)** | Configuración estándar de instancias EC2 en el diagrama de Hito 2. | **IMDSv2 Obligatorio (`HttpTokens=required`)** tanto en el Launch Template `dcl-dev-lt-web` como en la instancia de operación `dcl-dev-ops-web`. | Endurecimiento de seguridad operativa para bloquear ataques de *Server-Side Request Forgery (SSRF)* que intenten robar credenciales temporales del rol IAM. |
| **Superficie de Administración en EC2 Web** | Acceso administrativo tradicional durante despliegues. | **Eliminación del puerto SSH (22)** en las instancias web y aprovisionamiento 100 % automatizado mediante `User Data` y servicios `systemd`. | Reduce la superficie de ataque expuesta a Internet (solo puerto HTTP/80 abierto) y garantiza que cualquier instancia lanzada por el ASG nazca configurada sin intervención humana. |

---

## 3. HITO 4 — PREPARACIÓN OPERATIVA: SEGURIDAD, IDENTIDADES, LOGS, MÉTRICAS, ALARMA Y EVIDENCIA OPERACIONAL (5 %)

> **Alcance en el Proyecto Digital Café Luna:** Esta sección documenta la preparación operativa de la solución del proyecto (controles de identidad, seguridad de red, telemetría, detección de anomalías y respuesta basada en evidencia), integrando los criterios de operación segura sobre la arquitectura de Digital Café Luna.

### 3.1 Identidad y Principio de Mínimo Privilegio (`RNF-2`)

Ningún componente de Digital Café Luna utiliza credenciales estáticas (*Access Keys* `AKIA...`) en código fuente, variables de entorno ni scripts `User Data`. Todas las cargas de trabajo en EC2 obtienen credenciales temporales rotadas automáticamente por **AWS STS** a través de su **IAM Instance Profile** y **IMDSv2**:

| Identidad / IAM Role | Workload / Actor que lo Asume | Permisos Exactos Otorgados (`Action`) | Recurso Acotado (`Resource` ARN) | Justificación de Mínimo Privilegio |
| :--- | :--- | :--- | :--- | :--- |
| **`dcl-dev-role-web`**<br>*(Policy: `dcl-dev-policy-s3-state`)* | Instancias EC2 del Auto Scaling Group (`dcl-dev-asg-web` vía `dcl-dev-lt-web`) | `s3:GetObject` | `arn:aws:s3:::dcl-dev-state-<account-id>-team-01/state/dcl-state.json` | Las instancias web solo necesitan leer el objeto de estado/catálogo; no pueden listar otros buckets, borrar objetos (`s3:DeleteObject`) ni modificar políticas. |
| **`dcl-dev-role-lab2-sqs`** | Procesos de órdenes `producer.py` y `consumer.py` en EC2 | `sqs:SendMessage`, `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes` | `arn:aws:sqs:us-east-1:<account-id>:dcl-dev-orders-queue` | Autoriza únicamente la operación de la cola de pedidos del proyecto; prohíbe `sqs:*` o eliminar la cola (`sqs:DeleteQueue`). |
| **`dcl-dev-role-lab3-ops`**<br>*(Profile: `dcl-dev-profile-lab3-ops`)* | Workload web e ingesta de telemetría (`amazon-cloudwatch-agent` en `dcl-dev-ops-web`) | `logs:CreateLogStream`, `logs:DescribeLogStreams`, `logs:PutLogEvents` | `arn:aws:logs:us-east-1:<account-id>:log-group:/dcl/dev/ops:*` | La EC2 actúa exclusivamente como **productora de logs**. No tiene permisos de `CloudWatchFullAccess` ni puede crear/borrar Log Groups, filtros o alarmas (tareas reservadas a la identidad administradora del equipo). |

---

### 3.2 Controles de Seguridad Aplicados a la Solución (`RNF-1`, `RNF-6`)

1. **Enforzamiento de IMDSv2 (`HttpTokens=required`):** Todas las consultas al servicio de metadatos (`169.254.169.254`) exigen solicitar primero un token temporal mediante `PUT http://169.254.169.254/latest/api/token` con cabecera `X-aws-ec2-metadata-token-ttl-seconds`.
2. **Erradicación de SSH (Puerto 22) en Capa Web:** El Security Group de la aplicación web (`dcl-dev-sg-lab3` / `dcl-dev-sg-web`) permite únicamente tráfico entrante `TCP/80 (HTTP)`. Toda la configuración del servidor (`dcl-app.service` y `amazon-cloudwatch-agent`) se inyecta de forma desatendida mediante `User Data`.
3. **Defensa en Profundidad en Red (Route Tables + Security Groups encadenados + NACLs):**
   - Subredes privadas asociadas a `dcl-rt-private` sin ruta a Internet Gateway.
   - Security Group privado (`dcl-sg-private`) configurado mediante **referencia de Security Group** (solo acepta tráfico proveniente de `dcl-sg-public`), nunca desde `0.0.0.0/0`.
   - NACL privada (`dcl-nacl-private`) restringida en entrada y salida al bloque CIDR interno `10.20.0.0/16` (Regla 100 Allow, resto Deny implícito).
4. **Protección de Almacenamiento S3:** El bucket de persistencia tiene activadas las 4 restricciones de `BlockPublicAccess` (`BlockPublicAcls=true`, `IgnorePublicAcls=true`, `BlockPublicPolicy=true`, `RestrictPublicBuckets=true`) y cifrado en reposo SSE-S3.

---

### 3.3 Logs, Métricas y Alarma Funcional (`RNF-3`, `B05`)

La cadena de observabilidad transforma eventos de aplicación en señales accionables:

```text
[ Aplicación Web (/opt/dcl/app.py) ]
         │ Escribe eventos estructurados (UTC ISO-8601, level, path, status, message)
         ▼
[ Archivo Local: /var/log/dcl/app.log ]
         │ Recolectado por servicio systemd: amazon-cloudwatch-agent
         ▼
[ CloudWatch Log Group: /dcl/dev/ops ] (Retención: 7 días · Stream: {instance_id})
         │ Evaluado por Metric Filter: dcl-dev-error-filter (Patrón: "ERROR")
         ▼
[ CloudWatch Metric: DigitalCafeLuna/LAB3 -> ErrorCount ] (Value=1, DefaultValue=0)
         │ Evaluada cada 60s (Statistic: Sum >= 1, Datapoints: 1/1, TreatMissingData: notBreaching)
         ▼
[ CloudWatch Alarm: dcl-dev-ops-alarm ] ──▶ [ CloudWatch Dashboard: dcl-dev-ops-dashboard ]
```

- **Generación y Consulta de Logs Útiles:** La aplicación registra cada petición en `/var/log/dcl/app.log` con formato trazable:
  - Normal: `2026-10-13T19:57:10+00:00 INFO path=/health status=200 message=request_ok`
  - Falla: `2026-10-13T19:58:01+00:00 ERROR path=/simulate-error status=500 message=controlled_failure`
- **Métrica Personalizada (`ErrorCount`):** Extraída mediante el filtro `dcl-dev-error-filter`. Emite `1` ante cada línea con el patrón `ERROR` y `0` (`defaultValue=0`) cuando ingresan líneas `INFO`.
- **Alarma Funcional (`dcl-dev-ops-alarm`):** Evalúa `Sum(ErrorCount) >= 1` en periodos de `60 segundos`. Configurada con **`TreatMissingData = notBreaching`** para que los periodos sin tráfico entrante se interpreten como saludables (`OK`) y no generen falsos estados `INSUFFICIENT_DATA` o `ALARM`.
- **Dashboard Operacional (`dcl-dev-ops-dashboard`):** Consolida en tiempo real la serie temporal de `ErrorCount (HTTP 500)` y el widget de estado de `dcl-dev-ops-alarm`.

---

### 3.4 Evidencia Operacional y Patrón de Operación (`OK → ALARM → OK`)

Se validó la cadena operativa en **dos ciclos completos independientes** para comprobar su reproducibilidad determinista:

| Ciclo | `T0` (Solicitud `/simulate-error`) | `T1` (Evento `ERROR` en CW Logs) | `T2` (Métrica `ErrorCount = 1`) | `T3` (Alarma pasa a `ALARM`) | Retorno verificado a `OK` |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **Ciclo 1** | `19:58:01Z` | `19:58:09Z` *(+8s ingesta)* | `19:58:40Z` *(+31s filtro)* | `19:59:15Z` *(+35s ventana)* | `20:01:10Z` *(tras tráfico 200 OK)* |
| **Ciclo 2** | `20:12:53Z` | `20:13:01Z` *(+8s ingesta)* | `20:13:45Z` *(+44s filtro)* | `20:14:12Z` *(+27s ventana)* | `20:16:05Z` *(tras tráfico 200 OK)* |

#### Aplicación del Patrón de Evidencia Operacional (`Estado / Señal → Interpretación → Acción o Criterio Operacional`)

| Estado / Señal Observada | Interpretación Técnica | Acción o Criterio Operacional |
| :--- | :--- | :--- |
| **Señal 1:** Alarma `dcl-dev-ops-alarm` cambia de `OK` a `ALARM` en `T3` y el Dashboard muestra pico `Sum(ErrorCount) = 1` en `T2`. | Se produjo al menos una respuesta HTTP 500 en la capa de aplicación web durante la última ventana de evaluación de 60 segundos (`T0`–`T2`). | **Investigar en `/dcl/dev/ops`:** Filtrar el Log Stream `{instance_id}` en la ventana de tiempo de `T2` para identificar el `path`, `status` y `message` exactos antes de reiniciar instancias a ciegas. |
| **Señal 2:** Evento en CloudWatch Logs muestra `ERROR path=/simulate-error status=500 message=controlled_failure`, mientras `/health` responde `200 OK`. | El fallo está aislado en una ruta específica de la aplicación (`status=500`) y **no** corresponde a una caída de red, ni del servidor EC2 ni del almacenamiento S3. | **Criterio de contención:** No terminar la instancia EC2; suspender las invocaciones a la ruta defectuosa, verificar salud con `GET /health` y confirmar que en el siguiente minuto `Sum(ErrorCount) = 0` devuelve la alarma a `OK`. |
| **Señal 3:** Target en `dcl-dev-tg-web` pasa a `unhealthy` o instancia EC2 desaparece (`shutting-down` / `terminated`). | Pérdida real de capacidad de cómputo en una Availability Zone (`Running < Desired`). | **Recuperación automática IaaS:** El ALB deja de enviar tráfico al nodo caído inmediatamente y el ASG (`dcl-dev-asg-web`) lanza una nueva instancia desde `dcl-dev-lt-web`, la cual recupera el estado desde S3 sin intervención manual. |
| **Señal 4:** `ApproximateNumberOfMessages > 0` crece en `dcl-dev-orders-queue` mientras el productor responde OK. | El consumidor asíncrono (`consumer.py`) está detenido o lento, o un mensaje está fallando y reintentándose cada `VisibilityTimeout` (30s). | **Acción sobre worker:** Verificar el servicio consumidor y revisar `ApproximateReceiveCount`. Los pedidos de los clientes están seguros en la cola SQS y se procesarán al reactivar el consumidor. |

---

## 4. HITO 4 — COST DRIVERS Y RECOMENDACIONES FINOPS

### 4.1 Análisis bajo el Patrón de Evidencia de Costos

Siguiendo el patrón exigido: **`cost driver → evidencia → recomendación → impacto / trade-off`**

| Cost Driver Principal | Evidencia en la Solución del Equipo | Recomendación de Optimización FinOps | Impacto Presupuestal / Trade-off |
| :--- | :--- | :--- | :--- |
| **1. Balanceador de Carga (`dcl-dev-alb`) y Cómputo EC2 Continuo (`dcl-dev-asg-web` con `Desired=2`)** | El ALB genera cobro fijo por hora (~$0.0225/h + LCUs) y mantener 2 instancias `t3.micro` con IPv4 pública activa 24/7 acumula horas de cómputo e IPv4 pública ($0.005/h por IP) aun sin tráfico de usuarios. | **Escalamiento programado a cero (`Min=0, Desired=0`) fuera de sesiones de validación y eliminación temporal del ALB** tras cada entrega, conservando el Launch Template `dcl-dev-lt-web` y la VPC. | **Impacto:** Reducción de ~85–90 % del gasto mensual en entorno académico/dev.<br>**Trade-off:** Requiere ejecutar el comando de actualización del ASG (`Desired=2`) y recrear el ALB (~3 min) antes de una demostración en vivo. |
| **2. NAT Gateways por Zona de Disponibilidad (identificado en Hito 2)** | En el diseño de 3 capas de Hito 2, colocar 2 NAT Gateways en `us-east-1a` y `us-east-1b` cuesta ~$0.045/h cada uno (~$65 USD/mes fijos más $0.045/GB procesado), superando el presupuesto de $20 USD (`B09`). | **Prescindir de NAT Gateways permanentes en `dev` y utilizar VPC Gateway Endpoints gratuitos para Amazon S3** (`com.amazonaws.us-east-1.s3`) cuando las EC2 estén en subredes privadas. | **Impacto:** Ahorro del 100 % del cargo fijo por hora de NAT Gateway para el tráfico hacia S3.<br>**Trade-off:** Los Gateway Endpoints solo cubren S3 y DynamoDB; para descargar paquetes de SO en subredes privadas se requiere AMI preconstruida o NAT temporal. |
| **3. Base de Datos Relacional Administrada (RDS PostgreSQL Multi-AZ en diseño Hito 2)** | Una instancia RDS en configuración Multi-AZ duplica el costo de cómputo y almacenamiento provisto 24/7 frente a una instancia Single-AZ. | **Usar Single-AZ en entornos de desarrollo/pruebas (`dev`) y desacoplar pruebas de estado estático en Amazon S3 (`state/dcl-state.json`)**, reservando RDS Multi-AZ exclusivamente para producción. | **Impacto:** Reducción del 50 % en el costo de base de datos en entornos no productivos.<br>**Trade-off:** El entorno de desarrollo no tendrá failover automático entre AZs para la BD relacional durante pruebas. |
| **4. Ingestión y Almacenamiento Indefinido en CloudWatch Logs (`/dcl/dev/ops`)** | Por defecto, CloudWatch Logs conserva los registros de forma perpetua (`Never expire`), acumulando cargos mensuales por GB almacenado e ingerido. | **Fijar política de retención a 7 días (`retentionInDays = 7`) en `/dcl/dev/ops`** y registrar únicamente eventos relevantes (`INFO` de salud/órdenes y `ERROR`), desactivando logs verbosos de `stderr`. | **Impacto:** Mantiene el uso de CloudWatch 100 % dentro del *AWS Free Tier* (5 GB de logs, 10 métricas y 10 alarmas gratis).<br>**Trade-off:** Los logs históricos de más de una semana no estarán disponibles para auditoría forense directa en CloudWatch. |

---

## 5. INSTRUCCIONES DE OPERACIÓN Y RECONSTRUCCIÓN

> **Nota sobre Fronteras (Sección 10 de la Guía S15):** Hito 3 y Hito 4 no dependen de Terraform; por ello, a continuación se documenta el procedimiento reproducible mediante **AWS CLI** para reconstruir, operar, verificar y limpiar la solución base de Digital Café Luna en `us-east-1` (compatible además con los módulos de Terraform entregados en el componente diferenciado).

### 5.1 Variables Base y Verificación del Entorno (`us-east-1`)
```bash
export AWS_REGION="us-east-1"
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export BUCKET="dcl-dev-state-${ACCOUNT_ID}-team-01"
export QUEUE_NAME="dcl-dev-orders-queue"
```

### 5.2 Reconstrucción y Reactivación de la Solución
1. **Verificar red (`dcl-dev-vpc`), bucket S3 (`$BUCKET`) y objeto persistente (`state/dcl-state.json`):**
   ```bash
   aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Name,Values=dcl-dev-vpc" --output table
   aws s3api head-object --region us-east-1 --bucket "$BUCKET" --key state/dcl-state.json
   ```
2. **Reactivar capacidad del Auto Scaling Group (`dcl-dev-asg-web`) y verificar Target Group (`dcl-dev-tg-web`):**
   ```bash
   aws autoscaling update-auto-scaling-group \
     --region us-east-1 --auto-scaling-group-name dcl-dev-asg-web \
     --min-size 2 --desired-capacity 2 --max-size 4

   TG_ARN=$(aws elbv2 describe-target-groups --region us-east-1 --names dcl-dev-tg-web --query 'TargetGroups[0].TargetGroupArn' --output text)
   aws elbv2 describe-target-health --region us-east-1 --target-group-arn "$TG_ARN" --output table
   ```
3. **Comprobar respuesta del Application Load Balancer (`dcl-dev-alb`) y persistencia S3:**
   ```bash
   ALB_DNS=$(aws elbv2 describe-load-balancers --region us-east-1 --names dcl-dev-alb --query 'LoadBalancers[0].DNSName' --output text)
   curl -s "http://$ALB_DNS" | grep -E "Instance ID|Availability Zone|Estado"
   ```
4. **Operar la cola de pedidos SQS (`dcl-dev-orders-queue`):**
   ```bash
   export QUEUE_URL="https://sqs.us-east-1.amazonaws.com/${ACCOUNT_ID}/${QUEUE_NAME}"
   python3.11 producer.py DCL-001
   python3.11 consumer.py
   ```
5. **Verificar la cadena de observabilidad y probar la alarma (`dcl-dev-ops-alarm`):**
   ```bash
   # Estado normal (HTTP 200)
   curl -i http://$PUBLIC_OR_ALB_ENDPOINT/health

   # Provocar error controlado (HTTP 500) y observar transición OK -> ALARM
   date -u +"%Y-%m-%dT%H:%M:%SZ"
   curl -i http://$PUBLIC_OR_ALB_ENDPOINT/simulate-error

   aws cloudwatch describe-alarms --region us-east-1 --alarm-names "dcl-dev-ops-alarm" \
     --query "MetricAlarms[*].{Name:AlarmName,State:StateValue,Reason:StateReason}" --output table
   ```

### 5.3 Procedimiento de Cleanup Controlado (Ahorro de Costos entre Sesiones)
Para evitar cargos continuos sin perder la configuración base necesaria para la defensa de S16:
```bash
# 1. Llevar el Auto Scaling Group a 0 instancias activas
aws autoscaling update-auto-scaling-group \
  --region us-east-1 --auto-scaling-group-name dcl-dev-asg-web \
  --min-size 0 --desired-capacity 0 --max-size 4

# 2. Terminar instancias puntuales de prueba y verificar que quede 0 en estado running/stopped
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Name:Tags[?Key==`Name`]|[0].Value}' --output table
```

---

## 6. PROBLEMAS RELEVANTES ENCONTRADOS Y DECISIONES ADOPTADAS

| ID | Problema Relevante Encontrado | Diagnóstico / Causa Raíz | Decisión Técnica Adoptada |
| :---: | :--- | :--- | :--- |
| **P-01** | **Falta de failover automático al tener instancias EC2 separadas en dos AZs (Lab Evolutivo 2).** | Distribuir `dcl-dev-web-a` (`1a`) y `dcl-dev-web-b` (`1b`) provee redundancia de zona, pero si `A` se detiene, el cliente que apunta a la IP de `A` no es redirigido automáticamente a `B`. | Se incorporó el **Application Load Balancer (`dcl-dev-alb`)** con *health checks* en `dcl-dev-tg-web` y el **Auto Scaling Group (`dcl-dev-asg-web`)**, logrando un único endpoint DNS, exclusión automática de nodos caídos y reemplazo de capacidad (`desired=2`). |
| **P-02** | **Pérdida del estado local cuando el ASG reemplaza una instancia EC2 terminada.** | Al terminar una instancia EC2 (`Prueba B: Terminate`), el ASG lanza una instancia nueva con disco raíz limpio, perdiendo cualquier archivo guardado únicamente en el sistema de archivos local. | Se externalizó el estado persistente hacia el bucket privado **Amazon S3 (`state/dcl-state.json`)** y se actualizó el **Launch Template (`dcl-dev-lt-web`)** con el IAM Role `dcl-dev-role-web` (`s3:GetObject`) e **IMDSv2**, garantizando que toda instancia nueva recupere el estado automáticamente al arrancar. |
| **P-03** | **Riesgo de pérdida de pedidos cuando el proceso consumidor se detiene o falla.** | En una comunicación directa síncrona, si el procesador de órdenes cae, las compras enviadas por los clientes se pierden o devuelven error inmediato. | Se desacopló el flujo mediante **Amazon SQS Standard (`dcl-dev-orders-queue`)** con `VisibilityTimeout=30s` y borrado explícito (`DeleteMessage`) solo tras procesamiento exitoso, permitiendo acumular *backlog* con consumidor apagado y reintentar mensajes fallidos (`DCL-FAIL-001`). |
| **P-04** | **Alarma en estado `INSUFFICIENT_DATA` durante periodos sin errores o sin tráfico.** | El filtro `defaultValue=0` solo emite un datapoint `0` cuando ingresan logs `INFO`. Si no hay tráfico en un minuto, no se emiten puntos de datos y la alarma por defecto queda indeterminada. | Se configuró explícitamente **`TreatMissingData = notBreaching`** en `dcl-dev-ops-alarm` y se demostró la diferencia técnica entre `defaultValue=0` en el Metric Filter y el tratamiento de ausencias en la alarma. |
| **P-05** | **Bloqueo inicial de comunicación ICMP hacia la subred privada.** | La instancia privada en `10.20.110.0/24` rechazaba paquetes desde la instancia pública porque su Security Group no incluía la regla de entrada referenciada. | Se configuró `dcl-sg-private` autorizando ICMP exclusivamente desde el Security Group `dcl-sg-public` (sin abrir `0.0.0.0/0`), validando el paso de `100% packet loss` a `0% packet loss`. |

---

## 7. ROLES Y CONTRIBUCIONES CONCRETAS (GRUPO 1)

| Integrante | Rol | Contribución Concreta en Hitos 3 y 4 |
| :--- | :--- | :--- |
| **Paulina Velásquez Londoño** | **Arquitectura de Soluciones** | Lideró la coherencia arquitectónica entre el diseño revisado de Hito 2 y el despliegue real en Hitos 3 y 4; validó la separación entre cómputo efímero (EC2 ASG) y persistencia externa (S3 `state/dcl-state.json`) y documentó las diferencias diseño vs. implementación. |
| **Luis Alejandro Castrillón Pulgarín** | **Cloud / IaC Engineer** | Desplegó y configuró la infraestructura de red Multi-AZ (`dcl-dev-vpc`), el balanceador `dcl-dev-alb`, el Target Group `dcl-dev-tg-web`, el Launch Template `dcl-dev-lt-web` con `User Data` e IMDSv2, el Auto Scaling Group `dcl-dev-asg-web` y el agente unificado de CloudWatch. |
| **Martín Valencia Vallejo** | **Security / CloudOps Engineer** | Implementó los roles e Instance Profiles de mínimo privilegio (`dcl-dev-role-web`, `dcl-dev-role-lab2-sqs`, `dcl-dev-role-lab3-ops`) sin *Access Keys*, configuró el filtro de métricas `ErrorCount`, la alarma `dcl-dev-ops-alarm` y ejecutó los dos ciclos operacionales `OK → ALARM → OK`. |
| **Alberto Cervantes Forero** | **FinOps y Documentación** | Ejecutó el análisis de *cost drivers* reales (ALB, EC2 ASG, NAT Gateways, RDS Multi-AZ y retención de logs a 7 días), aplicó el esquema de etiquetado `dcl:*`, estructuró las matrices de evidencia de Hitos 3 y 4 y consolidó el procedimiento de operación y *cleanup*. |

---

## 8. MATRIZ DE EVIDENCIA — HITO 3 (IMPLEMENTACIÓN)

| Elemento | Evidencia / Referencia en el Repositorio | Resultado Comprobado | Decisión / Observación |
| :--- | :--- | :--- | :--- |
| **Arquitectura implementada** | Diagrama actualizado (Sección 1.2) y capturas `VPC.png`, `Subnets.png`, `ALBTable.png`, `ASG.png`, `SQSDetails.png`. | VPC `10.20.0.0/16` Multi-AZ (`us-east-1a/1b`), ALB `dcl-dev-alb`, ASG `dcl-dev-asg-web` (`2/2/4`), S3 privado y cola SQS `dcl-dev-orders-queue` operativos. | Evolución directa desde Hito 2; se omitieron NAT Gateways permanentes en `dev` por optimización FinOps sin perder aislamiento privado. |
| **Flujo funcional** | Peticiones a `http://$ALB_DNS`, lectura de `state/dcl-state.json` en S3 y flujo de órdenes `DCL-001` en SQS (`HTTPResponses.png`, `HappyPath/`). | El ALB distribuye peticiones HTTP 200 entre instancias EC2 en distintas AZs; cada instancia muestra su estado local efímero y el estado persistente común leído desde S3. | Cumple la cadena completa: `entrada → procesamiento → integración → persistencia → evidencia`. |
| **Integración / mensajería** | Scripts `producer.py` y `consumer.py` sobre `dcl-dev-orders-queue` (`ConsumerOFFProducerON3Messages.png`, `ReactivarConsumerSeProcesaCola.png`). | Con consumidor detenido, el productor envió `DCL-002..004` acumulando `Backlog=3`; al reactivar el consumidor, los 3 mensajes se procesaron (`Backlog=0`). Fallo `DCL-FAIL-001` reintentado tras `VisibilityTimeout=30s`. | Demuestra desacoplamiento temporal/lógico y entrega *at-least-once* (`RF-2`, `B04`). |
| **Validación** | Pruebas V-01 a V-05: Ping privado por SG (`PingWithICMPSecurityGroup.jpeg`), `Reboot` vs `Terminate` en ASG (`ASGDuringProofB.jpeg`, `NewTargets.png`) y persistencia S3 tras reemplazo de EC2. | Al terminar una instancia EC2, el ASG lanzó automáticamente una nueva instancia con nuevo `Instance ID` y `boot_time`, conservando intacto `state/dcl-state.json` desde S3. | Confirma empíricamente que el cómputo es reemplazable y el estado persistente es independiente (`RF-3`, `RF-4`). |
| **Problema relevante** | Pérdida de estado local al reemplazar instancias en ASG y ausencia de failover sin ALB (Problemas P-01, P-02 y P-03). | Incorporación de ALB + ASG, externalización del estado a S3 mediante Launch Template `dcl-dev-lt-web` con IAM Role y cola SQS para pedidos. | Las decisiones adoptadas resolvieron los puntos únicos de fallo sin sobredimensionar la arquitectura. |

---

## 9. MATRIZ DE EVIDENCIA — HITO 4 (PREPARACIÓN OPERATIVA)

| Elemento | Evidencia / Referencia en el Repositorio | Interpretación / Acción Operacional |
| :--- | :--- | :--- |
| **Identidad / mínimo privilegio** | Roles `dcl-dev-role-web` (`s3:GetObject` sobre `state/dcl-state.json`), `dcl-dev-role-lab2-sqs` (4 acciones sobre `dcl-dev-orders-queue`) y `dcl-dev-role-lab3-ops` (`PutLogEvents` sobre `/dcl/dev/ops`). Capturas `IAMRole.png`, `IAMSettings.png`, `EC2InstanceProfile.png`. | Cero *Access Keys* estáticas en código o disco. Cada componente usa credenciales STS temporales vía Instance Profile acotadas al ARN exacto del recurso que necesita (`RNF-2`). |
| **Seguridad** | `IMDSv2 Required` (`HttpTokens=required`), Security Group web solo con puerto `TCP/80` (sin SSH 22), S3 con `BlockPublicAccess=true`, `dcl-sg-private` por referencia de SG y `dcl-nacl-private` (`Public_SG.png`, `Private_SG.png`, `NACLs.png`). | Mitiga extracción de credenciales por SSRF, elimina exposición de administración remota SSH en el tier web y garantiza aislamiento estricto entre capas (`RNF-1`, `RNF-6`). |
| **Logs / métricas** | Archivo `/var/log/dcl/app.log` enviado por `amazon-cloudwatch-agent` a `/dcl/dev/ops` (retención 7 días) y Metric Filter `dcl-dev-error-filter` (`Patrón: ERROR` → `ErrorCount`, `value=1`, `default=0`). Capturas `CloudWatch.png`, `CloudWatchLogEvents.png`, `CloudWatchMetrics.png`. | Permite distinguir tráfico saludable (`INFO status=200`) de fallas de aplicación (`ERROR status=500`) y cuantificarlas en series de tiempo con resolución de 1 minuto. |
| **Alarma** | Alarma `dcl-dev-ops-alarm` (`Sum >= 1` en 60s, `1 out of 1`, `TreatMissingData=notBreaching`) y panel `dcl-dev-ops-dashboard`. Capturas `T0SimulatedError.png`, `T1Logs.png`, `T2SumErrorCount.png`, `T3Alarm.png`, `T3AlarmRetornoOK.png`. | Dos ciclos comprobados (`OK → ALARM → OK` con trazabilidad `T0–T3`). Ante `ALARM`, el operador correlaciona la ventana en `ErrorCount` con el log stream en `/dcl/dev/ops`, aísla la ruta `/simulate-error` y verifica la recuperación con `/health`. |
| **Cost drivers** | Análisis de generadores de costo (Sección 4.1): ALB + EC2 ASG 24/7, NAT Gateways por AZ, RDS Multi-AZ y retención de logs en CloudWatch (`RNF-4`, `B09`). | Se aplicó retención de 7 días en `/dcl/dev/ops`, se evitaron NAT Gateways continuos en `dev`, se etiquetaron los recursos con `dcl:*` y se estableció el apagado programado (`Desired=0` en ASG) fuera de sesiones de prueba. |
| **Operación / reconstrucción** | Comandos de operación, validación y *cleanup* documentados paso a paso (Sección 5) junto con el Launch Template `dcl-dev-lt-web` y scripts `User Data` / Python. | Cualquier integrante del equipo puede levantar la capacidad del ASG (`Desired=2`), validar el flujo de extremo a extremo, provocar y diagnosticar la alarma, y ejecutar el *cleanup* de recursos de cobro continuo. |

---
*Fin del Artefacto del Estudiante · Hitos 3 y 4 Integrados (S15) — Digital Café Luna · Grupo 1 · Universidad EAFIT*
