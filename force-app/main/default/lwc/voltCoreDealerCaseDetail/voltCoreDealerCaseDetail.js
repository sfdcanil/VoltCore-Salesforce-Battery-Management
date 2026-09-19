import { LightningElement, api, wire } from 'lwc';

import getDealerCase
    from '@salesforce/apex/VoltCoreDealerDashboardController.getDealerCase';


export default class VoltCoreDealerCaseDetail
    extends LightningElement {


    // =========================================================
    // CASE ID
    // =========================================================

    @api caseId;


    // =========================================================
    // CASE DATA
    // =========================================================

    caseRecord;


    // =========================================================
    // UI STATE
    // =========================================================

    isLoading = true;

    errorMessage;


    // =========================================================
    // LOAD CASE
    // =========================================================

    @wire(getDealerCase, { caseId: '$caseId' })
    wiredCase({ data, error }) {

        if (data) {

            this.caseRecord = data;

            this.errorMessage = undefined;

            this.isLoading = false;

        } else if (error) {

            console.error(
                'Dealer case detail error:',
                error
            );

            this.caseRecord = undefined;

            this.errorMessage =
                error?.body?.message ||
                'Unable to load case details.';

            this.isLoading = false;

        }

    }


    // =========================================================
    // CASE AVAILABLE
    // =========================================================

    get hasCase() {

        return !!this.caseRecord;

    }


    // =========================================================
    // STATUS CSS CLASS
    // =========================================================

    get statusClass() {

        if (!this.caseRecord?.status) {

            return 'status-badge';

        }


        const status =
            this.caseRecord.status.toLowerCase();


        if (
            status.includes('closed') ||
            status.includes('resolved')
        ) {

            return 'status-badge status-closed';

        }


        if (
            status.includes('progress') ||
            status.includes('working')
        ) {

            return 'status-badge status-progress';

        }


        if (
            status.includes('new') ||
            status.includes('open')
        ) {

            return 'status-badge status-open';

        }


        return 'status-badge';

    }


    // =========================================================
    // BACK TO CASE LIST
    // =========================================================

    handleBack() {

        this.dispatchEvent(
            new CustomEvent('backtocases')
        );

    }

}
