import { LightningElement } from 'lwc';

export default class VoltCoreLeadForm extends LightningElement {

    successMessage;
    errorMessage;

    handleSuccess(event) {

        const leadId = event.detail.id;

        console.log('Lead created:', leadId);

        this.successMessage =
            'Thank you! Your dealer enquiry has been submitted successfully.';

        this.errorMessage = undefined;

        const inputFields = this.template.querySelectorAll(
            'lightning-input-field'
        );

        inputFields.forEach(field => {
            field.reset();
        });
    }

    handleError(event) {

        console.error('Lead creation failed:', event.detail);

        this.errorMessage =
            'Something went wrong while submitting your enquiry. Please try again.';

        this.successMessage = undefined;
    }
}