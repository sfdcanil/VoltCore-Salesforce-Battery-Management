@RestResource(urlMapping='/razorpay/webhook/*')
global without sharing class RazorpayWebhook {

    @HttpPost
    global static void handleWebhook() {

        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;

        try {
            // 1. Validate request body
            if (request.requestBody == null) {
                sendResponse(response, 400, 'Request body is missing');
                return;
            }

            // Signature must use the original raw body
            String rawBody = request.requestBody.toString();

            // 2. Read webhook secret
            Razorpay_Webhook_Setting__mdt setting =
                Razorpay_Webhook_Setting__mdt.getInstance('Default');

            if (
                setting == null ||
                String.isBlank(setting.Webhook_Secret__c)
            ) {
                sendResponse(
                    response,
                    500,
                    'Webhook secret is not configured'
                );
                return;
            }

            // 3. Read Razorpay signature
            String receivedSignature =
                request.headers.get('X-Razorpay-Signature');

            // Fallback for lower-case header
            if (String.isBlank(receivedSignature)) {
                receivedSignature =
                    request.headers.get('x-razorpay-signature');
            }

            if (String.isBlank(receivedSignature)) {
                sendResponse(
                    response,
                    401,
                    'Razorpay signature is missing'
                );
                return;
            }

            // 4. Generate expected signature
            Blob generatedMac = Crypto.generateMac(
                'HmacSHA256',
                Blob.valueOf(rawBody),
                Blob.valueOf(setting.Webhook_Secret__c)
            );

            String expectedSignature =
                EncodingUtil.convertToHex(generatedMac);

            if (
                !expectedSignature.equalsIgnoreCase(
                    receivedSignature.trim()
                )
            ) {
                System.debug('Razorpay webhook signature mismatch');

                sendResponse(
                    response,
                    401,
                    'Invalid webhook signature'
                );
                return;
            }

            // 5. Parse webhook JSON
            Map<String, Object> webhookData =
                (Map<String, Object>)
                JSON.deserializeUntyped(rawBody);

            String eventName =
                getStringValue(webhookData, 'event');

            System.debug('Razorpay event: ' + eventName);

            // Only process completed Payment Links
            if (eventName != 'payment_link.paid') {
                sendResponse(
                    response,
                    200,
                    'Event ignored: ' + eventName
                );
                return;
            }

            Map<String, Object> payload =
                (Map<String, Object>) webhookData.get('payload');

            if (payload == null) {
                sendResponse(response, 400, 'Payload is missing');
                return;
            }

            // 6. Read Payment Link entity
            Map<String, Object> paymentLinkWrapper =
                (Map<String, Object>) payload.get('payment_link');

            Map<String, Object> paymentLinkEntity =
                paymentLinkWrapper == null
                ? null
                : (Map<String, Object>)
                    paymentLinkWrapper.get('entity');

            if (paymentLinkEntity == null) {
                sendResponse(
                    response,
                    400,
                    'Payment Link entity is missing'
                );
                return;
            }

            String paymentLinkId =
                getStringValue(paymentLinkEntity, 'id');

            String referenceId =
                getStringValue(paymentLinkEntity, 'reference_id');

            // 7. Read Payment entity
            Map<String, Object> paymentWrapper =
                (Map<String, Object>) payload.get('payment');

            Map<String, Object> paymentEntity =
                paymentWrapper == null
                ? null
                : (Map<String, Object>)
                    paymentWrapper.get('entity');

            if (paymentEntity == null) {
                sendResponse(
                    response,
                    400,
                    'Payment entity is missing'
                );
                return;
            }

            String razorpayPaymentId =
                getStringValue(paymentEntity, 'id');

            String paymentStatus =
                getStringValue(paymentEntity, 'status');

            String razorpayOrderId =
                getStringValue(paymentEntity, 'order_id');

            // 8. Get Order ID from order entity when necessary
            if (String.isBlank(razorpayOrderId)) {
                Map<String, Object> orderWrapper =
                    (Map<String, Object>) payload.get('order');

                Map<String, Object> orderEntity =
                    orderWrapper == null
                    ? null
                    : (Map<String, Object>)
                        orderWrapper.get('entity');

                razorpayOrderId =
                    getStringValue(orderEntity, 'id');
            }

            // Additional Order ID fallback
            if (String.isBlank(razorpayOrderId)) {
                razorpayOrderId =
                    getStringValue(
                        paymentLinkEntity,
                        'order_id'
                    );
            }

            // 9. Find transaction ID / RRN
            String transactionId;

            Map<String, Object> acquirerData =
                (Map<String, Object>)
                paymentEntity.get('acquirer_data');

            if (acquirerData != null) {
                // UPI/card/bank transaction reference
                transactionId =
                    getStringValue(acquirerData, 'rrn');

                if (String.isBlank(transactionId)) {
                    transactionId =
                        getStringValue(
                            acquirerData,
                            'upi_transaction_id'
                        );
                }

                if (String.isBlank(transactionId)) {
                    transactionId =
                        getStringValue(
                            acquirerData,
                            'bank_transaction_id'
                        );
                }

                if (String.isBlank(transactionId)) {
                    transactionId =
                        getStringValue(
                            acquirerData,
                            'auth_code'
                        );
                }
            }

            // Some test payments may not provide a separate RRN
            if (String.isBlank(transactionId)) {
                transactionId = razorpayPaymentId;
            }

            System.debug(
                'Payment Link ID: ' + paymentLinkId
            );
            System.debug(
                'Reference ID: ' + referenceId
            );
            System.debug(
                'Payment ID: ' + razorpayPaymentId
            );
            System.debug(
                'Order ID: ' + razorpayOrderId
            );
            System.debug(
                'Payment status: ' + paymentStatus
            );
            System.debug(
                'Transaction ID: ' + transactionId
            );

            if (
                String.isBlank(paymentLinkId) ||
                String.isBlank(razorpayPaymentId)
            ) {
                sendResponse(
                    response,
                    400,
                    'Required Razorpay IDs are missing'
                );
                return;
            }

            // 10. Find Salesforce Payment record
            List<Payment__c> paymentRecords =
                new List<Payment__c>();

            // First try reference_id.
            // The Payment Link reference_id should contain Payment__c Id.
            Id salesforcePaymentId;

            if (
                !String.isBlank(referenceId) &&
                (
                    referenceId.length() == 15 ||
                    referenceId.length() == 18
                )
            ) {
                try {
                    salesforcePaymentId = (Id) referenceId;
                } catch (Exception invalidIdError) {
                    salesforcePaymentId = null;
                }
            }

            if (salesforcePaymentId != null) {
                paymentRecords = [
                    SELECT
                        Id,
                        Payment_Link_Id__c,
                        Razorpay_Order_Id__c,
                        Razorpay_Payment_Id__c,
                        Transaction_Id__c,
                        Payment_status__c
                    FROM Payment__c
                    WHERE Id = :salesforcePaymentId
                    WITH SYSTEM_MODE
                    LIMIT 1
                ];
            }

            // If reference_id does not match, find by Payment Link ID
            if (paymentRecords.isEmpty()) {
                paymentRecords = [
                    SELECT
                        Id,
                        Payment_Link_Id__c,
                        Razorpay_Order_Id__c,
                        Razorpay_Payment_Id__c,
                        Transaction_Id__c,
                        Payment_status__c
                    FROM Payment__c
                    WHERE Payment_Link_Id__c = :paymentLinkId
                    WITH SYSTEM_MODE
                    LIMIT 1
                ];
            }

            if (paymentRecords.isEmpty()) {
                // Do not return 200 here.
                // Razorpay should retry the failed webhook.
                sendResponse(
                    response,
                    500,
                    'No Payment__c found for Payment Link: ' +
                    paymentLinkId
                );
                return;
            }

            Payment__c paymentRecord = paymentRecords[0];

            // 11. Handle duplicate webhook safely
            if (
                paymentRecord.Payment_status__c == 'Success' &&
                paymentRecord.Razorpay_Payment_Id__c ==
                    razorpayPaymentId
            ) {
                sendResponse(
                    response,
                    200,
                    'Webhook was already processed'
                );
                return;
            }

            // 12. Update all Payment fields
            paymentRecord.Payment_status__c = 'Success';
            paymentRecord.Razorpay_Payment_Id__c =
                razorpayPaymentId;
            paymentRecord.Razorpay_Order_Id__c =
                razorpayOrderId;
            paymentRecord.Transaction_Id__c =
                transactionId;

            Database.update(
                paymentRecord,
                AccessLevel.SYSTEM_MODE
            );

            System.debug(
                'Salesforce Payment updated: ' +
                paymentRecord.Id
            );

            sendResponse(
                response,
                200,
                'Webhook processed successfully'
            );

        } catch (Exception error) {
            String errorMessage =
                'Webhook Error: ' +
                error.getTypeName() +
                ' - ' +
                error.getMessage() +
                ' | Line: ' +
                error.getLineNumber();

            System.debug(LoggingLevel.ERROR, errorMessage);

            sendResponse(
                response,
                500,
                errorMessage
            );
        }
    }

    private static String getStringValue(
        Map<String, Object> source,
        String key
    ) {
        if (
            source == null ||
            source.get(key) == null
        ) {
            return null;
        }

        return String.valueOf(source.get(key));
    }

    private static void sendResponse(
        RestResponse response,
        Integer statusCode,
        String message
    ) {
        response.statusCode = statusCode;

        response.addHeader(
            'Content-Type',
            'application/json'
        );

        response.responseBody = Blob.valueOf(
            JSON.serialize(
                new Map<String, Object>{
                    'statusCode' => statusCode,
                    'message' => message
                }
            )
        );
    }
}