/**
 * @author      ICASTILLOF
 * @since       09/07/2026
 * @desc        Service para gestionar el envío automático de alquileres al proceso
 *              de aprobación financiera (VRT_APR_FinancialApproval).
 *
 *              Se lanza cuando un VRT_Rental__c tiene un VRT_DIV_TotalCost__c > 3000
 *              (umbral de entrada del Approval Process).
 *
 *              El envío se realiza mediante Approval.process() en bloque para
 *              respetar los límites de governor.
 *
 * @history     09/07/2026 - ICASTILLOF - Creación de la clase
 */
public with sharing class VRT_SRV_ApprovalManager {

    // ──────────────────────────────────────────────────────────────────────
    // Constantes
    // ──────────────────────────────────────────────────────────────────────

    /** Umbral de coste total a partir del cual se requiere aprobación financiera */
    public static final Decimal APPROVAL_THRESHOLD = 3000;

    /** Nombre API del proceso de aprobación */
    private static final String APPROVAL_PROCESS_NAME = 'VRT_APR_FinancialApproval';

    /** Comentario estándar incluido al enviar a aprobación */
    private static final String SUBMISSION_COMMENT =
        'Envío automático: el coste total supera los ' + APPROVAL_THRESHOLD + '€.';

    // ──────────────────────────────────────────────────────────────────────
    // Método principal – After Insert
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Evalúa los alquileres recién insertados y envía a aprobación
     *          aquellos cuyo coste total supere el umbral definido.
     *          Debe invocarse en contexto after insert.
     * @param   newRentals Lista de VRT_Rental__c insertados (trigger.new)
     */
    public static void submitForApprovalOnInsert(List<VRT_Rental__c> newRentals) {
        if (newRentals == null || newRentals.isEmpty()) {
            return;
        }

        List<VRT_Rental__c> toSubmit = new List<VRT_Rental__c>();
        for (VRT_Rental__c rental : newRentals) {
            if (requiresApproval(rental)) {
                toSubmit.add(rental);
            }
        }

        if (!toSubmit.isEmpty()) {
            submitApprovalRequests(toSubmit);
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Método principal – After Update
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Evalúa los alquileres actualizados y envía a aprobación aquellos
     *          cuyo coste total haya cambiado y ahora supere el umbral.
     *          Solo se envían registros que NO estaban previamente por encima del
     *          umbral (evita reenvíos innecesarios).
     *          Debe invocarse en contexto after update.
     * @param   oldMap Map con los registros en su estado previo
     * @param   newMap Map con los registros en su estado actual
     */
    public static void submitForApprovalOnUpdate(Map<Id, VRT_Rental__c> oldMap,
                                                  Map<Id, VRT_Rental__c> newMap) {
        if (oldMap == null || newMap == null) {
            return;
        }

        List<VRT_Rental__c> toSubmit = new List<VRT_Rental__c>();

        for (Id rentalId : newMap.keySet()) {
            VRT_Rental__c oldRental = oldMap.get(rentalId);
            VRT_Rental__c newRental = newMap.get(rentalId);

            // Enviar solo si el coste ha cambiado y ahora supera el umbral
            // pero antes no lo superaba (evitar reenvíos)
            if (requiresApproval(newRental) && !requiresApproval(oldRental)) {
                toSubmit.add(newRental);
            }
        }

        if (!toSubmit.isEmpty()) {
            submitApprovalRequests(toSubmit);
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Lógica de evaluación
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Determina si un alquiler requiere aprobación financiera.
     *          Condiciones: coste total > umbral y estado = 'Reservado'
     *          (solo se envían a aprobación los alquileres en estado Reservado).
     * @param   rental Registro de alquiler a evaluar
     * @return  true si requiere aprobación, false en caso contrario
     */
    public static Boolean requiresApproval(VRT_Rental__c rental) {
        if (rental == null) {
            return false;
        }
        Decimal totalCost = rental.VRT_DIV_TotalCost__c != null
            ? rental.VRT_DIV_TotalCost__c
            : 0;
        return totalCost > APPROVAL_THRESHOLD
            && rental.VRT_SEL_Status__c == 'Reservado';
    }

    // ──────────────────────────────────────────────────────────────────────
    // Envío bulk de solicitudes de aprobación
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Construye y envía las solicitudes de aprobación en bloque
     *          usando Approval.process(). Los errores individuales se registran
     *          con System.debug para depuración sin detener el flujo completo.
     * @param   rentals Lista de registros a enviar a aprobación
     */
    private static void submitApprovalRequests(List<VRT_Rental__c> rentals) {
        List<Approval.ProcessSubmitRequest> requests = new List<Approval.ProcessSubmitRequest>();

        for (VRT_Rental__c rental : rentals) {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(rental.Id);
            req.setSubmitterId(UserInfo.getUserId());
            req.setProcessDefinitionNameOrId(APPROVAL_PROCESS_NAME);
            req.setComments(SUBMISSION_COMMENT);
            req.setSkipEntryCriteria(false);
            requests.add(req);// rentals y requests tienen el mismo orden de contenido
        }

        // Enviar todas las solicitudes en bloque
        List<Approval.ProcessResult> results = Approval.process(requests, false);//process() devuelve una lista con el mismo orden que requests
        /* Cuando Approval.process() procesa una request con éxito, Salesforce ejecuta automáticamente todo lo que el Approval Process tiene configurado.
         * Se establece con req.setProcessDefinitionNameOrId(APPROVAL_PROCESS_NAME), de modo que apunta a VRT_APR_FinancialApproval, es decir, al fichero
         * force-app\main\default\approvalProcesses\VRT_Rental__c.VRT_APR_FinancialApproval.approvalProcess-meta.xml */
        // Registrar errores para depuración
        for (Integer i = 0; i < results.size(); i++) {
            Approval.ProcessResult result = results[i];
            if (!result.isSuccess()) {
                String errorMsg = '';
                for (Database.Error err : result.getErrors()) {
                    errorMsg += err.getMessage() + '; ';
                }
                System.debug(LoggingLevel.WARN,
                    'VRT_SRV_ApprovalManager: Error al enviar a aprobación el registro ' +
                    rentals[i].Id + ': ' + errorMsg); //rentals, requests y results presentan el mismo orden de contenidos
            }
        }
    }
}
