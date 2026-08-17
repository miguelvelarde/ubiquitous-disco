# Modelo de dominio y base de datos

Versión: 0.2 — Diseño de dominio y persistencia

## 1. Decisiones generales

- La base de datos será PostgreSQL.
- La persistencia se diseñará antes de implementar las clases y servicios de aplicación.
- La V1 prioriza un modelo simple y explícito; no se incorporan capacidades que no formen parte de los requerimientos actuales.
- Los cargos conservan los valores históricos necesarios para reconstruir la obligación en el momento en que fue generada.

## 2. Domain Model

**Aggregate Roots definidos:**
- Owner
- Department
- CondominiumSettings
- ServiceCatalog
- RecurringService
- Charge
- Payment
- Amenity
- Reservation

**Value Objects candidatos:**
- Money
- BillingPeriod

**Domain Service:** ChargeGenerationService  
**Domain Event:** ReservationConfirmed

## 3. Reservation → Charge

Se eligió la opción B. Reservation y Charge son Aggregates independientes. Reservation no crea directamente el Charge. Al confirmar una reservación se genera *ReservationConfirmed* y un handler coordina la creación del cargo.

## 4. Charges

- El Charge pertenece al Department.
- El importe queda congelado cuando se crea el cargo.
- ServiceCatalog.DefaultAmount aplica a nuevos cargos; cambios posteriores no modifican cargos existentes.
- OriginalAmount conserva el importe original y Amount representa el importe efectivo.
- Un servicio gratuito genera un Charge con importe $0.
- **Estados:** Pending, Paid, Waived y Cancelled.
- Overdue no se persiste; se deriva de Pending con DueDate vencida.
- Los cargos recurrentes deben ser idempotentes por RecurringService + BillingPeriod.

## 5. Bonificaciones y pago anual adelantado

No existe un concepto especial de pago anual. Si un departamento paga el año completo por adelantado, el usuario registra los cargos individualmente: 11 cargos se liquidan mediante sus respectivos pagos y el cargo restante se registra como *Waived*.

*Waived* no equivale a *Paid*; representa una bonificación o condonación.

## 6. Payments

- Relación acordada: Charge 1 ───── 0..1 Payment.
- Un cargo puede no tener pago o tener exactamente un pago.
- No existen pagos parciales en V1.
- Un pago no cubre múltiples cargos.
- PaymentAllocation queda fuera del modelo de V1.

## 7. Modelo relacional de V1

| Tabla                   | Definición                                                       |
|--------------------------|------------------------------------------------------------------|
| Owners                  | Información del propietario.                                     |
| Departments             | Unidad/departamento perteneciente a un propietario.              |
| CondominiumSettings     | Configuración global del condominio, incluyendo PaymentDueDay.   |
| ServiceCatalog          | Definición de servicios y DefaultAmount vigente.                 |
| RecurringServices       | Asignación de un servicio recurrente a un departamento, con vigencia. |
| Amenities               | Amenidades del condominio.                                       |
| Reservations            | Reservaciones y periodos de mantenimiento de amenidades.         |
| Charges                 | Obligaciones económicas individuales.                            |
| Payments                | Pagos individuales asociados a un único Charge.                  |

## 8. Reglas de persistencia

- PKs con UUID.
- Importes monetarios con numeric(12,2).
- Los importes no pueden ser negativos.
- Payment.ChargeId es UNIQUE para garantizar como máximo un pago por cargo.
- Estados mediante varchar + CHECK.
- BillingPeriod como date, usando el primer día del mes para cargos recurrentes.
- PaymentDueDay entre 1 y 31.
- Charge.SourceType: Recurring, Reservation o Extraordinary.
- Las referencias del origen del Charge deben ser consistentes mediante CHECK constraints.
- Índice único parcial para impedir cargos recurrentes duplicados por RecurringService + BillingPeriod.

## 9. Próximo paso

Validar el DDL PostgreSQL, especialmente Charges y sus restricciones de origen, importes, estados e idempotencia. Después se diseñarán los stored procedures.

## 10. Conclusión

El modelo V1 queda deliberadamente simple: cada cargo representa una obligación individual, cada pago liquida un único cargo y las bonificaciones se expresan mediante *Waived*. No se agrega PaymentAllocation porque no existe un requerimiento actual que necesite distribuir un pago entre varios cargos.

La separación entre Reservation y Charge se mantiene mediante *ReservationConfirmed*, permitiendo que la lógica de facturación evolucione sin acoplarla al Aggregate de reservaciones.
