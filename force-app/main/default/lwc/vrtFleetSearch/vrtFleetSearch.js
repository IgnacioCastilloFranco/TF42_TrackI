import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import searchVehicles from '@salesforce/apex/VRT_CTR_FleetSearch.searchVehicles';

export default class VrtFleetSearch extends NavigationMixin(LightningElement) {
    @track searchTerm = '';
    @track vehicles = [];
    @track isLoading = false;
    @track error;
    
    // Timer para el debounce
    delayTimeout;

    // Maneja el cambio de input de búsqueda con debounce de 300ms
    handleSearchChange(event) {
        window.clearTimeout(this.delayTimeout);
        const searchKey = event.target.value;
        this.searchTerm = searchKey;

        if (searchKey.trim().length >= 2) {
            this.isLoading = true;
            this.delayTimeout = setTimeout(() => {
                this.executeSearch(searchKey);
            }, 300);
        } else {
            this.vehicles = [];
            this.isLoading = false;
        }
    }

    // Llama al controlador Apex para realizar la búsqueda
    executeSearch(searchKey) {
        searchVehicles({ searchTerm: searchKey })
            .then((result) => {
                this.vehicles = result.map(veh => {
                    const isAvailable = veh.VRT_FLG_Available__c;
                    const type = veh.VRT_SEL_VehicleType__c ? veh.VRT_SEL_VehicleType__c.toLowerCase() : '';
                    
                    return {
                        ...veh,
                        fullName: `${veh.VRT_TXT_Brand__c} ${veh.VRT_TXT_Model__c}`,
                        iconName: type === 'moto' ? 'custom:custom54' : 'custom:custom31',
                        statusText: isAvailable ? 'Disponible' : (veh.VRT_SEL_Status__c || 'No Disponible'),
                        statusClass: isAvailable ? 'status-badge status-available' : 'status-badge status-unavailable'
                    };
                });
                this.error = undefined;
            })
            .catch((error) => {
                this.error = error;
                this.vehicles = [];
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Navega a la ficha de detalle del vehículo
    handleNavigateToRecord(event) {
        const vehicleId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: vehicleId,
                objectApiName: 'VRT_Vehicle__c',
                actionName: 'view'
            }
        });
    }

    // Getters auxiliares
    get hasResults() {
        return this.vehicles.length > 0 && !this.isLoading;
    }

    get showEmptyState() {
        return !this.isLoading && (!this.hasResults || this.searchTerm.trim().length < 2);
    }

    get emptyStateTitle() {
        if (this.searchTerm.trim().length < 2) {
            return 'Comienza a escribir...';
        }
        return 'No se encontraron vehículos';
    }

    get emptyStateSubtitle() {
        if (this.searchTerm.trim().length < 2) {
            return 'Introduce al menos 2 caracteres para buscar en la flota por marca, modelo o matrícula.';
        }
        return `No hay coincidencias en la flota para "${this.searchTerm}". Intenta buscar con otros términos.`;
    }
}
