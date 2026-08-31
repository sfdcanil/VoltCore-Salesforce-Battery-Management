public with sharing class RazorpayServices {

    // =====================================
    // Razorpay Order Response
    // =====================================
    public class RazorpayOrderResponse {
        public String id;
        public String entity;
        public Integer amount;
        public String status;
    }

    // =====================================
    // Razorpay Payment Link Response
    // =====================================
    public class RazorpayPaymentLinkResponse {
        public String id;
        public String short_url;
        public String status;
        public Integer amount;
        public String reference_id;
        public String order_id;
    }

    // =====================================
    // Fetch Payment Links Response
    // =====================================
    public class RazorpayPaymentLinkListResponse {
        public Integer count;
        public List<RazorpayPaymentLinkResponse> payment_links;
    }

    // =====================================
    // Create Razorpay Order
    // Retained for compatibility only.
    // Payment Link Flow does not call this.
    // =====================================
    public static RazorpayOrderResponse createOrder(
        Decimal amount,
        String receipt
    ) {
        if (amount == null || amount <= 0) {
            throw new CalloutException(
                'Order amount must be greater than zero.'
            );
        }

        HttpRequest request = new HttpRequest();

        request.setEndpoint(
            'callout:Razorpay_API/v1/orders'
        );

        request.setMethod('POST');

        request.setHeader(
            'Content-Type',
            'application/json'
        );

        Integer amountInPaise = Integer.valueOf(
            (amount * 100).setScale(0)
        );

        Map<String, Object> requestBody =
            new Map<String, Object>{
                'amount' => amountInPaise,
                'currency' => 'INR',
                'receipt' => receipt
            };

        request.setBody(
            JSON.serialize(requestBody)
        );

        HttpResponse response =
            new Http().send(request);

        System.debug(
            'Razorpay Order Status: ' +
            response.getStatusCode()
        );

        System.debug(
            'Razorpay Order Response: ' +
            response.getBody()
        );

        if (response.getStatusCode() >= 200 &&
            response.getStatusCode() < 300) {

            return (RazorpayOrderResponse)
                JSON.deserialize(
                    response.getBody(),
                    RazorpayOrderResponse.class
                );
        }

        throw new CalloutException(
            'Razorpay Order Error: ' +
            response.getBody()
        );
    }

    // =====================================
    // Compatibility method for old code
    // =====================================
    public static RazorpayPaymentLinkResponse createPaymentLink(
        Id paymentRecordId,
        String unusedRazorpayOrderId,
        Decimal amount,
        String receipt,
        String customerName,
        String customerEmail,
        String customerContact
    ) {
        return createOrRecoverPaymentLink(
            paymentRecordId,
            amount,
            receipt,
            customerName,
            customerEmail,
            customerContact
        );
    }

    // =====================================
    // Correct Payment Link method
    // =====================================
    public static RazorpayPaymentLinkResponse createPaymentLink(
        Id paymentRecordId,
        Decimal amount,
        String receipt,
        String customerName,
        String customerEmail,
        String customerContact
    ) {
        return createOrRecoverPaymentLink(
            paymentRecordId,
            amount,
            receipt,
            customerName,
            customerEmail,
            customerContact
        );
    }

    // =====================================
    // Create or Recover Payment Link
    // =====================================
    private static RazorpayPaymentLinkResponse
        createOrRecoverPaymentLink(
            Id paymentRecordId,
            Decimal amount,
            String receipt,
            String customerName,
            String customerEmail,
            String customerContact
        ) {

        if (paymentRecordId == null) {
            throw new CalloutException(
                'Payment Record ID is required.'
            );
        }

        if (amount == null || amount <= 0) {
            throw new CalloutException(
                'Payment amount must be greater than zero.'
            );
        }

        if (String.isBlank(customerEmail)) {
            throw new CalloutException(
                'Customer email is required.'
            );
        }

        if (String.isBlank(customerContact)) {
            throw new CalloutException(
                'Customer contact is required.'
            );
        }

        /*
         * Salesforce record ID is unique.
         * Do not use PY002/PY003 as Razorpay reference_id.
         */
        String uniqueReference =
            String.valueOf(paymentRecordId);

        Integer amountInPaise = Integer.valueOf(
            (amount * 100).setScale(0)
        );

        Payment__c currentPayment = [
            SELECT Id,
                   Payment_Link_Id__c,
                   Payment_Link__c,
                   Razorpay_Order_Id__c,
                   Payment_status__c,
                   Email_Sent__c
            FROM Payment__c
            WHERE Id = :paymentRecordId
            LIMIT 1
        ];

        // =====================================
        // Salesforce already contains the link
        // =====================================
        if (String.isNotBlank(
                currentPayment.Payment_Link_Id__c
            ) &&
            String.isNotBlank(
                currentPayment.Payment_Link__c
            )) {

            RazorpayPaymentLinkResponse savedLink =
                new RazorpayPaymentLinkResponse();

            savedLink.id =
                currentPayment.Payment_Link_Id__c;

            savedLink.short_url =
                currentPayment.Payment_Link__c;

            savedLink.order_id =
                currentPayment.Razorpay_Order_Id__c;

            savedLink.reference_id =
                uniqueReference;

            savedLink.status =
                'created';

            savedLink.amount =
                amountInPaise;

            return savedLink;
        }

        // =====================================
        // Check for an existing Razorpay Link
        // =====================================
        RazorpayPaymentLinkResponse existingLink =
            fetchPaymentLinkByReference(
                uniqueReference
            );

        if (existingLink != null) {

            validatePaymentLink(
                existingLink,
                amountInPaise
            );

            saveLinkAndSendEmail(
                currentPayment,
                existingLink
            );

            return existingLink;
        }

        // =====================================
        // Create new Razorpay Payment Link
        // =====================================
        HttpRequest linkRequest =
            new HttpRequest();

        linkRequest.setEndpoint(
            'callout:Razorpay_API/v1/payment_links'
        );

        linkRequest.setMethod('POST');

        linkRequest.setHeader(
            'Content-Type',
            'application/json'
        );

        Map<String, Object> customer =
            new Map<String, Object>{
                'name' => customerName,
                'email' => customerEmail,
                'contact' => customerContact
            };

        Map<String, Object> notes =
            new Map<String, Object>{
                'payment_name' => receipt,
                'salesforce_payment_id' =>
                    uniqueReference
            };

        Map<String, Object> paymentLinkBody =
            new Map<String, Object>{
                'amount' => amountInPaise,
                'currency' => 'INR',
                'reference_id' =>
                    uniqueReference,
                'description' =>
                    'Battery Payment - ' + receipt,
                'customer' => customer,
                'notes' => notes,
                'reminder_enable' => false
            };

        linkRequest.setBody(
            JSON.serialize(paymentLinkBody)
        );

        HttpResponse linkResponse =
            new Http().send(linkRequest);

        System.debug(
            'Payment Link Status: ' +
            linkResponse.getStatusCode()
        );

        System.debug(
            'Payment Link Response: ' +
            linkResponse.getBody()
        );

        // =====================================
        // New Payment Link created
        // =====================================
        if (linkResponse.getStatusCode() >= 200 &&
            linkResponse.getStatusCode() < 300) {

            RazorpayPaymentLinkResponse createdLink =
                (RazorpayPaymentLinkResponse)
                JSON.deserialize(
                    linkResponse.getBody(),
                    RazorpayPaymentLinkResponse.class
                );

            validatePaymentLink(
                createdLink,
                amountInPaise
            );

            saveLinkAndSendEmail(
                currentPayment,
                createdLink
            );

            return createdLink;
        }

        // =====================================
        // Handle duplicate/race condition
        // =====================================
        if (linkResponse.getStatusCode() == 400) {

            RazorpayPaymentLinkResponse recoveredLink =
                fetchPaymentLinkByReference(
                    uniqueReference
                );

            if (recoveredLink != null) {

                validatePaymentLink(
                    recoveredLink,
                    amountInPaise
                );

                saveLinkAndSendEmail(
                    currentPayment,
                    recoveredLink
                );

                return recoveredLink;
            }
        }

        throw new CalloutException(
            'Razorpay Payment Link Error: ' +
            linkResponse.getBody()
        );
    }

    // =====================================
    // Fetch Link using Salesforce record ID
    // =====================================
    private static RazorpayPaymentLinkResponse
        fetchPaymentLinkByReference(
            String uniqueReference
        ) {

        HttpRequest request =
            new HttpRequest();

        request.setEndpoint(
            'callout:Razorpay_API/v1/payment_links' +
            '?reference_id=' +
            EncodingUtil.urlEncode(
                uniqueReference,
                'UTF-8'
            )
        );

        request.setMethod('GET');

        request.setHeader(
            'Content-Type',
            'application/json'
        );

        HttpResponse response =
            new Http().send(request);

        System.debug(
            'Fetch Payment Link Status: ' +
            response.getStatusCode()
        );

        System.debug(
            'Fetch Payment Link Response: ' +
            response.getBody()
        );

        if (response.getStatusCode() >= 200 &&
            response.getStatusCode() < 300) {

            RazorpayPaymentLinkListResponse result =
                (RazorpayPaymentLinkListResponse)
                JSON.deserialize(
                    response.getBody(),
                    RazorpayPaymentLinkListResponse.class
                );

            if (result != null &&
                result.payment_links != null &&
                !result.payment_links.isEmpty()) {

                return result.payment_links[0];
            }

            return null;
        }

        throw new CalloutException(
            'Unable to fetch Razorpay Payment Link: ' +
            response.getBody()
        );
    }

    // =====================================
    // Validate Link
    // =====================================
    private static void validatePaymentLink(
        RazorpayPaymentLinkResponse link,
        Integer expectedAmount
    ) {
        if (link == null) {
            throw new CalloutException(
                'Razorpay Payment Link response is empty.'
            );
        }

        if (String.isBlank(link.id) ||
            String.isBlank(link.short_url)) {

            throw new CalloutException(
                'Razorpay Payment Link ID or URL is missing.'
            );
        }

        if (link.amount != null &&
            link.amount != expectedAmount) {

            throw new CalloutException(
                'Existing Razorpay Payment Link amount ' +
                'does not match the Salesforce amount.'
            );
        }

        /*
         * Do not attach an old paid/cancelled/expired link.
         */
        if (String.isNotBlank(link.status) &&
            !'created'.equalsIgnoreCase(
                link.status
            )) {

            throw new CalloutException(
                'Existing Razorpay Payment Link status is ' +
                link.status +
                '. Only an unpaid created link can be used.'
            );
        }
    }

    // =====================================
    // Send Email through Razorpay and
    // save the Link in Salesforce
    // =====================================
    private static void saveLinkAndSendEmail(
        Payment__c currentPayment,
        RazorpayPaymentLinkResponse link
    ) {
        Boolean emailSent =
            currentPayment.Email_Sent__c == true;

        /*
         * Razorpay sends the email.
         * Salesforce Messaging.sendEmail is not used.
         */
        if (!emailSent) {
            emailSent =
                sendPaymentLinkEmailThroughRazorpay(
                    link.id
                );
        }

        Payment__c paymentUpdate =
            new Payment__c(
                Id = currentPayment.Id,

                Razorpay_Order_Id__c =
                    link.order_id,

                Payment_Link_Id__c =
                    link.id,

                Payment_Link__c =
                    link.short_url,

                /*
                 * Status always remains Pending here.
                 * Webhook alone changes it to Success.
                 */
                Payment_status__c =
                    'Pending',

                Email_Sent__c =
                    emailSent
            );

        update paymentUpdate;
    }

    // =====================================
    // Razorpay Email Notification API
    // =====================================
    private static Boolean
        sendPaymentLinkEmailThroughRazorpay(
            String paymentLinkId
        ) {

        if (String.isBlank(paymentLinkId)) {
            throw new CalloutException(
                'Payment Link ID is required to send email.'
            );
        }

        HttpRequest request =
            new HttpRequest();

        request.setEndpoint(
            'callout:Razorpay_API/v1/payment_links/' +
            EncodingUtil.urlEncode(
                paymentLinkId,
                'UTF-8'
            ) +
            '/notify_by/email'
        );

        request.setMethod('POST');

        request.setHeader(
            'Content-Type',
            'application/json'
        );

        HttpResponse response =
            new Http().send(request);

        System.debug(
            'Razorpay Email Status: ' +
            response.getStatusCode()
        );

        System.debug(
            'Razorpay Email Response: ' +
            response.getBody()
        );

        if (response.getStatusCode() >= 200 &&
            response.getStatusCode() < 300) {

            Map<String, Object> responseBody =
                (Map<String, Object>)
                JSON.deserializeUntyped(
                    response.getBody()
                );

            if (responseBody != null &&
                responseBody.containsKey(
                    'success'
                )) {

                Boolean success =
                    (Boolean)
                    responseBody.get(
                        'success'
                    );

                if (success == true) {
                    return true;
                }
            }
        }

        throw new CalloutException(
            'Razorpay email notification failed: ' +
            response.getBody()
        );
    }
}