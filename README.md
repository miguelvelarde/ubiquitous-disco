# Condo Admin System

**Documento de Requerimientos Funcionales y de Dominio**
**Versión:** 0.1
**Estado:** Borrador inicial
**Fecha:** 8 de agosto de 2026

---

# 1. Propósito

El sistema tendrá como objetivo apoyar la administración operativa y financiera de un condominio residencial.

El sistema permitirá administrar:

* Departamentos y propietarios.
* Servicios ofrecidos por el condominio.
* Cargos recurrentes y extraordinarios.
* Pagos de mantenimiento y otros servicios.
* Servicios contratados por evento.
* Amenidades y áreas comunes.
* Mantenimientos de amenidades.
* Periodos de inhabilitación de amenidades.
* Reservaciones de amenidades.
* Estados de cuenta y reportes administrativos.

El sistema será utilizado como una herramienta administrativa local y estará diseñado para ejecutarse en una computadora portátil, sin depender de procesos de ejecución permanente en segundo plano.

---

# 2. Alcance inicial

El sistema cubrirá inicialmente los siguientes dominios funcionales:

## 2.1 Administración de propietarios y departamentos

Permitirá registrar y administrar:

* Propietarios.
* Departamentos.
* Edificio al que pertenece cada departamento.
* Número de departamento.
* Relación entre propietario y departamento.
* Información de contacto del propietario.
* Estado del departamento.

## 2.2 Administración de servicios

Permitirá definir un catálogo de servicios que pueden generar cargos a un departamento.

Ejemplos:

* Mantenimiento mensual.
* WiFi mensual.
* Renta de casa club.
* Renta de asadores.
* Otros servicios que puedan incorporarse posteriormente.

Cada servicio podrá clasificarse como:

* Recurrente.
* Por evento.
* Único/extraordinario.

Un servicio podrá tener costo o ser gratuito.

## 2.3 Administración de cargos

El sistema deberá representar las obligaciones económicas de cada departamento mediante cargos.

Un cargo representará una cantidad que un departamento debe pagar por un determinado servicio.

Los cargos podrán originarse por:

* Un servicio recurrente.
* Una reservación o servicio por evento.
* Un cargo extraordinario generado por un administrador.

El cargo deberá conservar su información histórica, incluyendo el monto y la fecha de vencimiento que tenía al momento de ser generado.

## 2.4 Administración de pagos

El sistema permitirá registrar el pago de los cargos.

Para la primera versión:

* No se contemplan pagos parciales.
* Un cargo debe pagarse completamente.
* Un cargo puede estar pendiente o pagado.
* Un cargo pagado deberá registrar la fecha del pago.
* Se deberá poder registrar el método de pago y una referencia cuando corresponda.

## 2.5 Administración de servicios recurrentes

Los servicios recurrentes representarán la configuración que determina que un departamento debe recibir periódicamente un determinado cargo.

Inicialmente se contemplan:

* Mantenimiento mensual.
* WiFi mensual.

Los servicios recurrentes no generarán cargos mediante un proceso ejecutándose permanentemente.

El sistema contará con una operación explícita para generar los cargos correspondientes a un periodo.

El proceso deberá ser idempotente: ejecutar varias veces la generación de cargos para el mismo periodo no deberá crear cargos duplicados.

## 2.6 Administración de fechas de pago

La fecha de vencimiento será configurable a nivel del condominio y será la misma para todos los departamentos.

La configuración deberá permitir definir el día del mes en que vencen los pagos recurrentes.

Ejemplo:

> Todos los cargos de mantenimiento correspondientes a agosto vencen el día 5 de agosto.

El cargo deberá almacenar la fecha de vencimiento concreta que le corresponda.

Esto permitirá conservar correctamente el historial aun cuando la configuración de la fecha de pago cambie posteriormente.

La configuración exacta del día de vencimiento queda pendiente de definir.

---

# 3. Modelo conceptual de facturación

El sistema distinguirá explícitamente entre:

**Servicio → Cargo → Pago**

## 3.1 Servicio

Define qué ofrece el condominio y bajo qué condiciones generales.

Ejemplos:

* Mantenimiento.
* WiFi.
* Casa club.
* Asador.

## 3.2 Cargo

Representa una obligación económica concreta de un departamento.

Ejemplo:

> Departamento A-101 debe $1,500 por concepto de mantenimiento correspondiente a agosto de 2026.

El cargo deberá conservar:

* Departamento.
* Servicio.
* Periodo, cuando corresponda.
* Fecha de vencimiento.
* Importe.
* Estado.
* Fecha de creación.

## 3.3 Pago

Representa la liquidación de un cargo.

Para la primera versión:

```text
Charge 1 ─────── 0..1 Payment
```

Un cargo podrá tener:

* Ningún pago → pendiente.
* Un pago completo → pagado.

No se contemplan pagos parciales en esta versión.

---

# 4. Generación de cargos

Debido a que el sistema será una aplicación local y no contará con procesos de ejecución permanente, la generación de cargos será una operación controlada por el usuario.

El administrador podrá seleccionar un periodo y ejecutar:

> Generar cargos del periodo.

El sistema deberá:

1. Identificar los servicios recurrentes activos.
2. Determinar qué cargos corresponden al periodo seleccionado.
3. Verificar si cada cargo ya existe.
4. Crear únicamente los cargos faltantes.
5. Calcular su fecha de vencimiento utilizando la configuración vigente.
6. Evitar cargos duplicados.

Ejemplo:

```text
Periodo: Agosto 2026

Mantenimiento
  Departamento A-101 → $1,500
  Departamento A-102 → $1,500
  Departamento B-201 → $1,500

WiFi
  Departamento A-101 → $300
  Departamento A-102 → $300
  Departamento B-201 → $300
```

Si la operación se ejecuta nuevamente, los cargos existentes no deberán duplicarse.

---

# 5. Estados de los cargos

Como mínimo, el sistema deberá contemplar:

* **Pending** — El cargo existe y no ha sido pagado.
* **Paid** — El cargo fue liquidado.
* **Cancelled** — El cargo fue cancelado.

El sistema deberá poder identificar cargos vencidos.

Un cargo pendiente cuya fecha de vencimiento ya haya pasado podrá ser identificado como **Overdue**.

La decisión de si `Overdue` será almacenado como estado o calculado dinámicamente queda pendiente de diseño.

---

# 6. Amenidades

El sistema deberá permitir administrar las amenidades y áreas comunes del condominio.

Ejemplos:

* Albercas.
* Casa club.
* Asadores.
* Gimnasio.
* Otras zonas comunes.

Cada amenidad podrá tener información como:

* Nombre.
* Descripción.
* Ubicación.
* Estado.
* Disponibilidad.

---

# 7. Mantenimiento de amenidades

El sistema deberá permitir registrar los mantenimientos realizados sobre las amenidades.

Cada registro podrá incluir:

* Amenidad.
* Fecha del mantenimiento.
* Descripción.
* Observaciones.
* Costo, cuando corresponda.
* Información adicional relevante.

El sistema deberá permitir consultar el historial de mantenimiento de una amenidad.

Ejemplo:

> Alberca principal — último mantenimiento: 3 de agosto de 2026.

---

# 8. Inhabilitación de amenidades

El sistema deberá permitir registrar periodos durante los cuales una amenidad no estuvo disponible.

El registro deberá contemplar:

* Amenidad.
* Fecha/hora de inicio.
* Fecha/hora de finalización.
* Motivo.
* Observaciones.

Ejemplos:

* Mantenimiento.
* Reparación.
* Limpieza.
* Evento privado.
* Otra causa administrativa.

El historial deberá permitir conocer cuándo y por qué una amenidad estuvo inhabilitada.

---

# 9. Reservaciones y servicios por evento

Los servicios que impliquen el uso de una amenidad durante un periodo determinado podrán manejarse mediante reservaciones.

Ejemplos:

* Renta de casa club.
* Renta de asador.

Una reservación deberá asociar, como mínimo:

* Amenidad.
* Departamento.
* Fecha/hora de inicio.
* Fecha/hora de finalización.
* Estado de la reservación.

Cuando un servicio por evento tenga costo, la reservación podrá generar un cargo asociado al departamento.

El sistema deberá evitar, en la medida de lo requerido por las reglas de negocio, reservaciones incompatibles para la misma amenidad y periodo.

---

# 10. Propietarios y departamentos

Un propietario podrá estar asociado con uno o más departamentos.

Un departamento tendrá un propietario asociado.

El diseño deberá permitir evolucionar posteriormente hacia escenarios como:

* Cambio de propietario.
* Historial de propietarios.
* Más de un propietario por departamento.
* Inquilinos.

Estos escenarios no forman parte necesariamente de la primera versión, pero no deberán impedirse desde el diseño conceptual.

---

# 11. Estado de cuenta

El sistema deberá permitir consultar el estado de cuenta de un departamento.

El estado de cuenta deberá mostrar como mínimo:

* Cargos.
* Periodo.
* Servicio.
* Fecha de vencimiento.
* Importe.
* Estado.
* Fecha de pago, cuando exista.

Ejemplo:

| Periodo     | Servicio      | Vencimiento | Importe | Estado    |
| ----------- | ------------- | ----------- | ------: | --------- |
| Agosto 2026 | Mantenimiento | 05/08/2026  |  $1,500 | Pagado    |
| Agosto 2026 | WiFi          | 05/08/2026  |    $300 | Pendiente |
| Agosto 2026 | Casa Club     | 15/08/2026  |    $500 | Pendiente |

El sistema deberá permitir identificar:

* Total pendiente.
* Total pagado.
* Cargos vencidos.
* Historial de pagos.

---

# 12. Reportes

El sistema deberá proporcionar inicialmente reportes relacionados con:

## 12.1 Estado de cuenta

Por departamento y, posteriormente, por propietario.

## 12.2 Pagos pendientes

Listado de departamentos con cargos pendientes.

## 12.3 Pagos realizados

Historial de pagos realizados durante un periodo.

## 12.4 Cargos vencidos

Listado de cargos cuya fecha de vencimiento ha pasado y que permanecen pendientes.

## 12.5 Servicios

Información sobre los servicios contratados/cobrados.

## 12.6 Mantenimiento de amenidades

Historial de mantenimientos realizados.

## 12.7 Disponibilidad de amenidades

Historial de periodos de inhabilitación.

Los requerimientos detallados de cada reporte serán definidos posteriormente.

---

# 13. Persistencia

La base de datos será implementada utilizando **PostgreSQL**.

El modelo inicial contemplará, como mínimo, las siguientes áreas:

```text
Owners
Departments

ServicesCatalog
RecurringServices
Charges
Payments

Amenities
AmenityMaintenance
AmenityAvailability

Reservations
```

La estructura definitiva de tablas y relaciones será definida después de validar el modelo de dominio.

---

# 14. Arquitectura tecnológica

El sistema utilizará:

* **C# / .NET** para el backend.
* **ASP.NET Core Web API** para la API RESTful.
* **PostgreSQL** como base de datos.
* **Blazor** para la interfaz de usuario.
* **Entity Framework Core** como tecnología de acceso a datos, sujeto a validación durante el diseño.
* Arquitectura basada en principios de **Domain Driven Design (DDD)**, aplicados de manera proporcional al tamaño y complejidad del sistema.

La aplicación será diseñada para ejecutarse localmente en una computadora portátil.

No se considera inicialmente:

* Infraestructura cloud.
* Procesos de background permanentes.
* Servicios de scheduling externos.
* Alta disponibilidad.
* Arquitectura distribuida.

---

# 15. Principios de diseño del dominio

El sistema deberá mantener una separación clara entre:

### Catálogo

Qué servicios existen.

### Configuración recurrente

Qué servicios deben generarse periódicamente.

### Cargo

Qué cantidad debe pagar un departamento.

### Pago

Qué cargo fue liquidado.

### Amenidad

Qué recurso físico administra el condominio.

### Reservación

Qué departamento utiliza una amenidad durante un periodo.

Esta separación deberá mantenerse tanto en el modelo de dominio como, en la medida de lo posible, en la arquitectura de la aplicación.

---

# 16. Reglas de negocio iniciales

### RN-001 — Un cargo pertenece a un departamento

Los cargos serán responsabilidad del departamento y no directamente del propietario.

El propietario podrá consultar indirectamente los cargos de los departamentos que tenga asociados.

### RN-002 — No existen pagos parciales

Un cargo deberá liquidarse completamente.

### RN-003 — Un cargo puede tener como máximo un pago

Un cargo pendiente no tendrá pagos asociados.

Una vez registrado el pago completo, el cargo pasará a estado pagado.

### RN-004 — Los servicios recurrentes generan cargos por periodo

Los servicios recurrentes deberán generar un cargo por cada periodo aplicable.

### RN-005 — No se permiten cargos recurrentes duplicados

Para una misma combinación de servicio recurrente, departamento y periodo deberá existir como máximo un cargo.

### RN-006 — La fecha de vencimiento es común

La fecha de vencimiento será configurable a nivel del condominio y aplicará a todos los departamentos.

### RN-007 — El cargo conserva su fecha histórica

Una vez generado un cargo, su fecha de vencimiento no deberá modificarse automáticamente debido a cambios posteriores en la configuración.

### RN-008 — La generación de cargos es manual

La generación de cargos se ejecutará como una operación iniciada por el administrador.

### RN-009 — La generación debe ser idempotente

Ejecutar repetidamente la generación de cargos para un mismo periodo no deberá generar duplicados.

### RN-010 — El importe del cargo queda registrado

El cargo deberá conservar el importe aplicado en el momento de su generación, independientemente de cambios posteriores en el catálogo de servicios.

---

# 17. Requerimientos no funcionales iniciales

## RNF-001 — Aplicación local

El sistema deberá poder ejecutarse en una computadora portátil sin requerir infraestructura de servidor externa.

## RNF-002 — Persistencia

La información deberá permanecer disponible después de cerrar y volver a abrir la aplicación.

## RNF-003 — Integridad

Las reglas que evitan cargos duplicados y pagos inconsistentes deberán protegerse también a nivel de persistencia cuando sea apropiado.

## RNF-004 — Mantenibilidad

La arquitectura deberá permitir agregar posteriormente nuevos tipos de servicios, amenidades y reglas sin modificar innecesariamente las funcionalidades existentes.

## RNF-005 — Auditoría

Las operaciones administrativas importantes deberán poder conservar información suficiente para conocer cuándo fueron realizadas y, cuando corresponda, por quién.

---

# 18. Elementos fuera de alcance inicial

Los siguientes elementos no forman parte de la primera versión salvo que posteriormente se decida lo contrario:

* Pagos parciales.
* Cargos con intereses o recargos.
* Integración con bancos.
* Procesamiento automático de pagos.
* Notificaciones automáticas por correo/SMS/WhatsApp.
* Multi-condominio.
* Arquitectura cloud.
* Procesamiento en background 24/7.
* Aplicación móvil.
* Portal para propietarios.
* Integración contable.

---

# 19. Pendientes por definir

Los siguientes puntos deberán resolverse durante las siguientes iteraciones:

1. Día exacto de vencimiento mensual.
2. Si existe periodo de tolerancia después del vencimiento.
3. Si existen recargos por pagos vencidos.
4. Reglas para cancelación de cargos.
5. Reglas para modificar cargos ya generados.
6. Métodos de pago aceptados.
7. Información requerida para registrar un pago.
8. Si los servicios gratuitos requieren reservación.
9. Reglas de reservación de amenidades.
10. Duración máxima de una reservación.
11. Anticipación mínima para reservar una amenidad.
12. Reglas para cancelar reservaciones.
13. Si una reservación genera el cargo inmediatamente o posteriormente.
14. Si los cambios de tarifa afectan únicamente cargos futuros.
15. Historial de propietarios de un departamento.
16. Reglas de permisos y usuarios administrativos.
17. Estrategia de respaldos de la base de datos local.
18. Formatos de exportación de reportes.

---

# 20. Dirección arquitectónica propuesta

La solución deberá evolucionar alrededor de los siguientes conceptos principales:

```text
Property Management
    ├── Owner
    └── Department

Billing
    ├── ServiceCatalog
    ├── RecurringService
    ├── Charge
    └── Payment

Amenities
    ├── Amenity
    ├── Maintenance
    ├── Availability
    └── Reservation
```

La relación conceptual principal de facturación será:

```text
ServiceCatalog
      │
      ├───────────────┐
      │               │
      ▼               ▼
RecurringService   Reservation
      │               │
      └───────┬───────┘
              ▼
            Charge
              │
              ▼
            Payment
```

Este modelo constituye la base conceptual de la primera iteración y podrá modificarse conforme se descubran nuevas reglas de negocio.

---

# 21. Estado del documento

Este documento representa la **versión inicial del requerimiento** y deberá considerarse un documento vivo.

Las decisiones tomadas durante el diseño, implementación y validación del sistema deberán reflejarse en versiones posteriores del documento.

**Versión actual: 0.1**

