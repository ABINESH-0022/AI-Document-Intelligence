import { LightningElement, wire } from 'lwc';
import getDocuments from '@salesforce/apex/DocumentManagementController.getDocuments';
import { refreshApex } from '@salesforce/apex';

export default class DocumentManagement extends LightningElement {

    documents = [];
    filteredDocuments = [];
    searchTerm = '';
    selectedType = 'All';
    selectedStatus = 'All';
    isLoading = true;
    error;
    wiredResult;
    sortedBy = 'Name';
    sortDirection = 'asc';

    columns = [
        {
            label: 'Document Name',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Name' },
                target: '_self'
            },
            sortable: true
        },
        { label: 'Document Type', fieldName: 'Document_Type__c', sortable: true },
        { label: 'Vendor Name', fieldName: 'Vendor_Name__c', sortable: true },
        { label: 'Document Number', fieldName: 'Document_Number__c', sortable: true },
        { label: 'Document Date', fieldName: 'Document_Date__c', type: 'date', sortable: true },
        { label: 'Total Amount', fieldName: 'Total_Amount__c', type: 'currency', sortable: true },
        { label: 'Processing Status', fieldName: 'Processing_Status__c', sortable: true },
        { label: 'Validation Status', fieldName: 'Validation_Status__c', sortable: true }
    ];

    typeOptions = [
        { label: 'All Types', value: 'All' },
        { label: 'Invoice', value: 'Invoice' },
        { label: 'Purchase Order', value: 'Purchase Order' },
        { label: 'Contract', value: 'Contract' },
        { label: 'Business Report', value: 'Business Report' },
        { label: 'Other', value: 'Other' }
    ];

    statusOptions = [
        { label: 'All Statuses', value: 'All' },
        { label: 'Uploaded', value: 'Uploaded' },
        { label: 'Processing', value: 'Processing' },
        { label: 'Completed', value: 'Completed' },
        { label: 'Failed', value: 'Failed' }
    ];

    @wire(getDocuments)
    loadDocuments(result) {
        this.wiredResult = result;

        if (result.data) {
            this.documents = result.data.map(doc => ({
                ...doc,
                recordUrl: '/' + doc.Id
            }));

            this.applyFilters();
            this.error = undefined;
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error;
            this.isLoading = false;
        }
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.applyFilters();
    }

    handleTypeFilter(event) {
        this.selectedType = event.detail.value;
        this.applyFilters();
    }

    handleStatusFilter(event) {
        this.selectedStatus = event.detail.value;
        this.applyFilters();
    }

    applyFilters() {
        this.filteredDocuments = this.documents.filter(doc => {
            const searchMatch =
                (doc.Name || '').toLowerCase().includes(this.searchTerm) ||
                (doc.Vendor_Name__c || '').toLowerCase().includes(this.searchTerm) ||
                (doc.Document_Number__c || '').toLowerCase().includes(this.searchTerm);

            const typeMatch =
                this.selectedType === 'All' ||
                doc.Document_Type__c === this.selectedType;

            const statusMatch =
                this.selectedStatus === 'All' ||
                doc.Processing_Status__c === this.selectedStatus;

            return searchMatch && typeMatch && statusMatch;
        });
    }

    handleSort(event) {
        const field = event.detail.fieldName;
        const direction = event.detail.sortDirection;

        this.sortedBy = field;
        this.sortDirection = direction;

        const sortField = field === 'recordUrl' ? 'Name' : field;

        this.filteredDocuments = [...this.filteredDocuments].sort((a, b) => {
            let first = a[sortField] || '';
            let second = b[sortField] || '';

            if (first > second) {
                return direction === 'asc' ? 1 : -1;
            }

            if (first < second) {
                return direction === 'asc' ? -1 : 1;
            }

            return 0;
        });
    }

    async handleRefresh() {
        this.isLoading = true;

        try {
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.error = error;
        } finally {
            this.isLoading = false;
        }
    }

    get showNoRecords() {
        return !this.isLoading && this.filteredDocuments.length === 0;
    }
}