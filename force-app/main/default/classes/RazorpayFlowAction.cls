public with sharing class RazorpayFlowAction {

    public class FlowInput {

        @InvocableVariable(
            required=true
            label='Payment Record ID'
        )
        public Id paymentId;

        @InvocableVariable(
            required=true
            label='Payment Amount'
        )
        public Decimal amount;

        @InvocableVariable(
            required=true
            label='Receipt'
        )
        public String receipt;

        @InvocableVariable(
            required=true
            label='Dealer Name'
        )
        public String customerName;

        @InvocableVariable(
            required=true
            label='Dealer Email'
        )
        public String customerEmail;

        @InvocableVariable(
            required=true
            label='Dealer Contact'
        )
        public String customerContact;
    }

    @InvocableMethod(
        label='Generate Razorpay Payment Link'
        description='Creates or recovers a Razorpay payment link and sends it by email'
        callout=true
    )
    public static void generatePaymentLink(
        List<FlowInput> inputs
    ) {
        for (FlowInput inputRecord : inputs) {

            if (inputRecord.paymentId == null) {
                continue;
            }

            if (inputRecord.amount == null ||
                inputRecord.amount <= 0) {

                throw new FlowActionException(
                    'Payment amount must be greater than zero.'
                );
            }

            if (String.isBlank(
                    inputRecord.customerEmail
                )) {

                throw new FlowActionException(
                    'Dealer email is required.'
                );
            }

            if (String.isBlank(
                    inputRecord.customerContact
                )) {

                throw new FlowActionException(
                    'Dealer contact is required.'
                );
            }

            /*
             * Do not create a separate Razorpay Order.
             * Payment Link response supplies order_id.
             */
            RazorpayServices.createPaymentLink(
                inputRecord.paymentId,
                inputRecord.amount,
                inputRecord.receipt,
                inputRecord.customerName,
                inputRecord.customerEmail,
                inputRecord.customerContact
            );
        }
    }

    public class FlowActionException
        extends Exception {
    }
}