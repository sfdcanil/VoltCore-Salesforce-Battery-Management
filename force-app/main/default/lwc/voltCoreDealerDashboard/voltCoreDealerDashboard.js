import { LightningElement } from 'lwc';

import getDealerDashboard
    from '@salesforce/apex/VoltCoreDealerDashboardController.getDealerDashboard';

export default class VoltCoreDealerDashboard extends LightningElement {

    dealer;

    isLoading = true;

    errorMessage;


    connectedCallback() {

        this.loadDealerDashboard();

    }


    async loadDealerDashboard() {

        this.isLoading = true;

        this.errorMessage = undefined;

        try {

            this.dealer =
                await getDealerDashboard();

        } catch (error) {

            console.error(
                'Dealer dashboard error:',
                error
            );

            this.dealer = undefined;

            this.errorMessage =
                error?.body?.message ||
                'Unable to load your dealer information.';

        } finally {

            this.isLoading = false;

        }

    }


    get fullName() {

        if (!this.dealer) {

            return '';

        }

        return [

            this.dealer.firstName,

            this.dealer.lastName

        ]

        .filter(Boolean)

        .join(' ');

    }


    get fullAddress() {

        if (!this.dealer) {

            return '';

        }

        return [

            this.dealer.billingStreet,

            this.dealer.billingCity,

            this.dealer.billingState,

            this.dealer.billingPostalCode,

            this.dealer.billingCountry

        ]

        .filter(Boolean)

        .join(', ');

    }


    get hasDealerData() {

        return !!this.dealer;

    }

}
