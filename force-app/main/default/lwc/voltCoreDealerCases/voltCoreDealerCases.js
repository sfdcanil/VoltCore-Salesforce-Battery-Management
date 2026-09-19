import { LightningElement, wire } from 'lwc';

import getDealerCases
    from '@salesforce/apex/VoltCoreDealerDashboardController.getDealerCases';

export default class VoltCoreDealerCases
    extends LightningElement {

    cases = [];
    isLoading = true;
    errorMessage;

    @wire(getDealerCases)
    wiredCases({ data, error }) {
        this.isLoading = false;

        if (data) {
            this.cases = data.map(caseRecord => ({
                ...caseRecord,
                statusClass:
                    this.getStatusClass(caseRecord.status)
            }));

            this.errorMessage = undefined;

        } else if (error) {
            console.error(
                'Dealer cases error:',
                error
            );

            this.cases = [];

            this.errorMessage =
                error?.body?.message ||
                'Unable to load your cases.';
        }
    }

    get hasCases() {
        return this.cases.length > 0;
    }

    get hasNoCases() {
        return (
            !this.isLoading &&
            !this.errorMessage &&
            this.cases.length === 0
        );
    }

    getStatusClass(status) {

        if (!status) {
            return 'status-badge';
        }

        const normalizedStatus =
            status.toLowerCase();

        if (
            normalizedStatus.includes('closed') ||
            normalizedStatus.includes('resolved')
        ) {
            return 'status-badge status-closed';
        }

        if (
            normalizedStatus.includes('progress') ||
            normalizedStatus.includes('working')
        ) {
            return 'status-badge status-progress';
        }

        if (
            normalizedStatus.includes('new') ||
            normalizedStatus.includes('open')
        ) {
            return 'status-badge status-open';
        }

        return 'status-badge';
    }

    handleCaseClick(event) {

        const caseId =
            event.currentTarget.dataset.id;

        if (!caseId) {
            return;
        }

        this.dispatchEvent(
            new CustomEvent('caseclick', {
                detail: {
                    caseId: caseId
                }
            })
        );
    }
}
