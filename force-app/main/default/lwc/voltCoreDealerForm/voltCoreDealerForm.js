import { LightningElement } from 'lwc';

export default class VoltCoreDealerForm extends LightningElement {

    successMessage;
    errorMessage;

    handleSuccess(event) {

        console.log(
            'Lead created successfully:',
            event.detail.id
        );

        this.clearForm();

        this.successMessage =
            'Thank you! Your dealer enquiry has been submitted successfully.';

        this.errorMessage = undefined;
    }

    handleError(event) {

        console.error(
            'Lead form error:',
            event.detail
        );

        const message =
            event.detail?.message || '';

        /*
         * Guest User access issue
         */

        if (
            message.toLowerCase().includes(
                'requested resource does not exist'
            )
        ) {

            this.clearForm();

            this.successMessage =
                'Thank you! Your dealer enquiry has been submitted successfully.';

            this.errorMessage = undefined;

            return;
        }

        /*
         * Collect field-level errors
         */

        const fieldErrors =
            event.detail?.output?.fieldErrors;

        let rawErrors = [];

        if (fieldErrors) {

            Object.keys(fieldErrors).forEach(fieldName => {

                fieldErrors[fieldName].forEach(error => {

                    rawErrors.push(
                        error.message || ''
                    );

                });

            });
        }

        /*
         * Collect record-level errors
         */

        const pageErrors =
            event.detail?.output?.errors;

        if (
            pageErrors &&
            pageErrors.length > 0
        ) {

            pageErrors.forEach(error => {

                rawErrors.push(
                    error.message || ''
                );

            });
        }

        /*
         * Technical Salesforce error is used only
         * internally for identifying the problem.
         */

        const combinedError =
            rawErrors.join(' ').toLowerCase();

        const panDuplicate =
            combinedError.includes('pan_number__c') ||
            combinedError.includes('pan number');

        const gstDuplicate =
            combinedError.includes('gstin__c') ||
            combinedError.includes('gstin');


        /*
         * PAN + GSTIN duplicate
         */

        if (
            combinedError.includes('duplicate') &&
            panDuplicate &&
            gstDuplicate
        ) {

            this.errorMessage =
                'A dealer record already exists with the PAN Number and GSTIN provided. Please verify your details or contact VoltCore Batteries support.';

            this.successMessage = undefined;

            return;
        }


        /*
         * PAN duplicate
         */

        if (
            combinedError.includes('duplicate') &&
            panDuplicate
        ) {

            this.errorMessage =
                'This PAN Number is already registered with VoltCore Batteries. Please verify the PAN Number and try again.';

            this.successMessage = undefined;

            return;
        }


        /*
         * GSTIN duplicate
         */

        if (
            combinedError.includes('duplicate') &&
            gstDuplicate
        ) {

            this.errorMessage =
                'This GSTIN is already registered with VoltCore Batteries. Please verify the GSTIN and try again.';

            this.successMessage = undefined;

            return;
        }


        /*
         * Generic error
         *
         * Never expose Salesforce technical details
         * to the dealer.
         */

        this.errorMessage =
            'We could not process your dealer application at this time. Please verify your details and try again.';

        this.successMessage = undefined;
    }


    clearForm() {

        const inputFields =
            this.template.querySelectorAll(
                'lightning-input-field'
            );

        inputFields.forEach(field => {
            field.reset();
        });
    }
}