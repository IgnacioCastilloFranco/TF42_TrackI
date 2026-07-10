import { LightningElement, api, wire } from 'lwc';
import getRentalsByAccount from '@salesforce/apex/VRT_CTR_RentalConsole.getRentalsByAccount';
import getRentalSummary from '@salesforce/apex/VRT_CTR_RentalConsole.getRentalSummary';
import { refreshApex } from '@salesforce/apex';

// Columnas de la datatable
const COLUMNS = [
    {
        label: 'Alquiler',
        fieldName: 'rentalUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_blank'
        },
        sortable: true
    },
    {
        label: 'Vehículo',
        fieldName: 'vehicleInfo',
        type: 'text',
        sortable: true
    },
    {
        label: 'Matrícula',
        fieldName: 'licensePlate',
        type: 'text'
    },
    {
        label: 'Fecha Inicio',
        fieldName: 'VRT_DAT_InitialDate__c',
        type: 'date',
        sortable: true
    },
    {
        label: 'Fecha Fin',
        fieldName: 'VRT_DAT_FinalDate__c',
        type: 'date',
        sortable: true
    },
    {
        label: 'Estado',
        fieldName: 'VRT_SEL_Status__c',
        type: 'text',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'statusClass' }
        }
    },
    {
        label: 'Pago',
        fieldName: 'VRT_SEL_PaymentStatus__c',
        type: 'text'
    },
    {
        label: 'Coste Total',
        fieldName: 'VRT_DIV_TotalCost__c',
        type: 'currency',
        typeAttributes: { currencyCode: 'EUR' },
        sortable: true,
        cellAttributes: { alignment: 'left' }
    }
];

// Opciones del filtro de estado
const STATUS_OPTIONS = [
    { label: 'Todos', value: 'Todos' },
    { label: 'Reservado', value: 'Reservado' },
    { label: 'En curso', value: 'En curso' },
    { label: 'Completado', value: 'Completado' },
    { label: 'Cancelado', value: 'Cancelado' }
];

export default class VrtRentalConsole extends LightningElement {
    @api recordId; // contendrá el Id de la cuenta que el usuario está viendo.

    columns = COLUMNS;
    statusOptions = STATUS_OPTIONS;
    selectedStatus = 'Todos';

    // Datos crudos del wire
    wiredRentalsResult;
    wiredSummaryResult;

    // Datos procesados
    allRentals = [];
    filteredRentals = [];
    summary = {};

    isLoading = true;
    error;

    // ──────────────────────────────────────────────────────────────────────
    // Wire: Obtener alquileres
    // ──────────────────────────────────────────────────────────────────────

    @wire(getRentalsByAccount, { accountId: '$recordId' }) // El $ delante de recordId indica que es reactivo: cuando Salesforce asigna el valor, los @wire se ejecutan automáticament
    wiredRentals(result) {
        this.wiredRentalsResult = result;
        const { data, error } = result;

        if (data) {
            this.allRentals = data.map(rental => ({
                ...rental,
                rentalUrl: '/' + rental.Id,
                vehicleInfo: rental.VRT_LKP_Vehicle__r
                    ? rental.VRT_LKP_Vehicle__r.VRT_TXT_Brand__c + ' ' +
                    rental.VRT_LKP_Vehicle__r.VRT_TXT_Model__c
                    : '—',
                licensePlate: rental.VRT_LKP_Vehicle__r
                    ? rental.VRT_LKP_Vehicle__r.VRT_TXT_LicensePlate__c
                    : '—',
                statusClass: this.getStatusClass(rental.VRT_SEL_Status__c)
            }));
            this.applyFilter();
            this.error = undefined;
        } else if (error) {
            this.error = this.reduceErrors(error);
            this.allRentals = [];
            this.filteredRentals = [];
        }
        this.isLoading = false;
    }

    // ──────────────────────────────────────────────────────────────────────
    // Wire: Obtener resumen KPIs
    // ──────────────────────────────────────────────────────────────────────

    @wire(getRentalSummary, { accountId: '$recordId' })
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        const { data, error } = result;

        if (data) {
            this.summary = data;
        } else if (error) {
            this.summary = {};
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Getters
    // ──────────────────────────────────────────────────────────────────────

    get hasRentals() {
        return this.filteredRentals && this.filteredRentals.length > 0;
    }

    get totalRentals() {
        return this.summary.totalRentals || 0;
    }

    get activeRentals() {
        return this.summary.activeRentals || 0;
    }

    get completedRentals() {
        return this.summary.completedRentals || 0;
    }

    get cancelledRentals() {
        return this.summary.cancelledRentals || 0;
    }

    get totalCost() {
        const cost = this.summary.totalCost || 0;
        return new Intl.NumberFormat('es-ES', {
            style: 'currency',
            currency: 'EUR'
        }).format(cost);
    }

    get tableTitle() {
        const count = this.filteredRentals ? this.filteredRentals.length : 0;
        return `Alquileres (${count})`;
    }

    // ──────────────────────────────────────────────────────────────────────
    // Handlers
    // ──────────────────────────────────────────────────────────────────────

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.applyFilter();
    }

    handleRefresh() {
        this.isLoading = true;
        Promise.all([
            refreshApex(this.wiredRentalsResult),
            refreshApex(this.wiredSummaryResult)
        ]).finally(() => {
            this.isLoading = false;
        });
    }

    // ──────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────

    applyFilter() {
        if (this.selectedStatus === 'Todos') {
            this.filteredRentals = [...this.allRentals];
        } else {
            this.filteredRentals = this.allRentals.filter(
                r => r.VRT_SEL_Status__c === this.selectedStatus
            );
        }
    }

    getStatusClass(status) {
        switch (status) {
            case 'En curso': return 'slds-text-color_success';
            case 'Completado': return 'slds-text-color_default';
            case 'Cancelado': return 'slds-text-color_error';
            case 'Reservado': return 'slds-text-color_weak';
            default: return '';
        }
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'Error desconocido';
    }
}
