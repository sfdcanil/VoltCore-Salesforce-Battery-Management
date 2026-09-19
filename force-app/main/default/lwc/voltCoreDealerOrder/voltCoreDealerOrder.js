import { LightningElement, track } from 'lwc';

import getAvailableProducts from '@salesforce/apex/PartnerProductOrderController.getAvailableProducts';
import submitOrder from '@salesforce/apex/PartnerProductOrderController.submitOrder';


export default class Voltcoredealerorder extends LightningElement {

    @track products = [];

    @track errorMessage = '';

    @track successData = null;

    isLoading = true;

    isSubmitting = false;


    /*
     * ============================================================
     * LIFECYCLE
     * ============================================================
     */
    connectedCallback() {
        this.loadProducts();
    }


    /*
     * ============================================================
     * LOAD PRODUCTS
     * ============================================================
     */
    async loadProducts() {

        this.isLoading = true;
        this.errorMessage = '';

        try {

            const result = await getAvailableProducts();


            console.log(
                'PRODUCTS FROM APEX:',
                result
            );


            console.log(
                'MAPPING PRODUCTS:',
                result
            );


            this.products =
                (result || []).map(product => {

                    return {
                        productId:
                            product.productId,

                        pricebookEntryId:
                            product.pricebookEntryId,

                        productName:
                            product.productName,

                        productCode:
                            product.productCode,

                        unitPrice:
                            product.unitPrice,

                        selected:
                            false,

                        quantity:
                            1,

                        quantityDisabled:
                            true,

                        lineTotal:
                            0
                    };
                });


            console.log(
                'FINAL PRODUCTS STATE:',
                JSON.stringify(this.products)
            );


        } catch (error) {

            console.error(
                'Dealer product loading error:',
                error
            );


            this.errorMessage =
                this.getErrorMessage(
                    error,
                    'Unable to load products.'
                );


        } finally {

            this.isLoading = false;
        }
    }


    /*
     * ============================================================
     * PRODUCT SELECTION
     * ============================================================
     */
    handleProductSelection(event) {

        const productId =
            event.target.dataset.productId;

        const selected =
            event.target.checked;


        this.products =
            this.products.map(product => {

                if (
                    product.productId === productId
                ) {

                    const quantity =
                        selected
                            ? Number(product.quantity || 1)
                            : 1;


                    return {
                        ...product,

                        selected:
                            selected,

                        quantity:
                            quantity,

                        quantityDisabled:
                            !selected,

                        lineTotal:
                            selected
                                ? this.calculateLineTotal(
                                    product.unitPrice,
                                    quantity
                                )
                                : 0
                    };
                }


                return product;
            });
    }


    /*
     * ============================================================
     * QUANTITY CHANGE
     * ============================================================
     */
    handleQuantityChange(event) {

        const productId =
            event.target.dataset.productId;

        let quantity =
            Number(event.target.value);


        if (
            !Number.isInteger(quantity) ||
            quantity <= 0
        ) {

            quantity = 1;

            event.target.value = 1;
        }


        if (
            quantity > 100000
        ) {

            quantity = 100000;

            event.target.value = 100000;
        }


        this.products =
            this.products.map(product => {

                if (
                    product.productId === productId
                ) {

                    return {
                        ...product,

                        quantity:
                            quantity,

                        lineTotal:
                            product.selected
                                ? this.calculateLineTotal(
                                    product.unitPrice,
                                    quantity
                                )
                                : 0
                    };
                }


                return product;
            });
    }


    /*
     * ============================================================
     * LINE TOTAL
     * ============================================================
     *
     * This is only for browser display.
     *
     * Salesforce Apex independently determines the
     * authoritative UnitPrice during order creation.
     */
    calculateLineTotal(
        unitPrice,
        quantity
    ) {

        return (
            Number(unitPrice || 0) *
            Number(quantity || 0)
        );
    }


    /*
     * ============================================================
     * SELECTED PRODUCTS
     * ============================================================
     */
    get selectedProducts() {

        return this.products.filter(
            product => product.selected
        );
    }


    /*
     * ============================================================
     * SELECTED PRODUCT COUNT
     * ============================================================
     *
     * Used by the HTML:
     *
     * {selectedProductCount}
     */
    get selectedProductCount() {

        return this.selectedProducts.length;
    }


    /*
     * ============================================================
     * TOTAL QUANTITY
     * ============================================================
     *
     * Used by the HTML:
     *
     * {totalQuantity}
     */
    get totalQuantity() {

        return this.selectedProducts.reduce(
            (total, product) => {

                return (
                    total +
                    Number(product.quantity || 0)
                );

            },
            0
        );
    }


    /*
     * ============================================================
     * ORDER TOTAL
     * ============================================================
     */
    get orderTotal() {

        return this.selectedProducts.reduce(
            (total, product) => {

                return (
                    total +
                    this.calculateLineTotal(
                        product.unitPrice,
                        product.quantity
                    )
                );

            },
            0
        );
    }


    /*
     * ============================================================
     * FORMATTED ORDER TOTAL
     * ============================================================
     */
    get formattedOrderTotal() {

        return this.formatCurrency(
            this.orderTotal
        );
    }


    /*
     * ============================================================
     * HAS PRODUCTS
     * ============================================================
     *
     * Used by:
     *
     * <template if:true={hasProducts}>
     */
    get hasProducts() {

        return (
            !this.isLoading &&
            this.products.length > 0
        );
    }


    /*
     * ============================================================
     * EMPTY STATE
     * ============================================================
     */
    get showEmptyState() {

        return (
            !this.isLoading &&
            !this.errorMessage &&
            this.products.length === 0
        );
    }


    /*
     * ============================================================
     * SUBMIT BUTTON
     * ============================================================
     *
     * Disable the button when:
     *
     * - Products are loading
     * - Order is being submitted
     * - No product is selected
     */
    get disableSubmit() {

        return (
            this.isLoading ||
            this.isSubmitting ||
            this.selectedProductCount === 0
        );
    }


    /*
     * ============================================================
     * SUCCESS MESSAGE
     * ============================================================
     */
    get successMessage() {

        return this.successData !== null;
    }


    /*
     * ============================================================
     * SUBMITTED OPPORTUNITY NAME
     * ============================================================
     */
    get submittedOpportunityName() {

        if (!this.successData) {
            return '';
        }


        return this.successData.opportunityName || '';
    }


    /*
     * ============================================================
     * SUBMITTED PRODUCT COUNT
     * ============================================================
     */
    get submittedProductCount() {

        if (!this.successData) {
            return 0;
        }


        return this.successData.productCount || 0;
    }


    /*
     * ============================================================
     * SUBMITTED AMOUNT
     * ============================================================
     */
    get submittedAmount() {

        if (!this.successData) {
            return '';
        }


        return this.formatCurrency(
            this.successData.opportunityAmount
        );
    }


    /*
     * ============================================================
     * SUBMIT ORDER
     * ============================================================
     */
    async handleSubmit() {

        this.errorMessage = '';

        this.successData = null;


        const selected =
            this.selectedProducts;


        /*
         * --------------------------------------------------------
         * Validate selection
         * --------------------------------------------------------
         */
        if (
            selected.length === 0
        ) {

            this.errorMessage =
                'Please select at least one product.';

            return;
        }


        /*
         * --------------------------------------------------------
         * Validate quantities
         * --------------------------------------------------------
         */
        for (
            const product of selected
        ) {

            const quantity =
                Number(product.quantity);


            if (
                !Number.isInteger(quantity) ||
                quantity <= 0
            ) {

                this.errorMessage =
                    `Please enter a valid quantity for ${product.productName}.`;

                return;
            }


            if (
                quantity > 100000
            ) {

                this.errorMessage =
                    `Quantity for ${product.productName} cannot exceed 100000.`;

                return;
            }
        }


        this.isSubmitting = true;


        try {

            /*
             * ====================================================
             * IMPORTANT SECURITY RULE
             * ====================================================
             *
             * The browser sends ONLY:
             *
             *   productId
             *   quantity
             *
             * The browser does NOT send:
             *
             *   price
             *   pricebookEntryId
             *   accountId
             *   opportunityId
             *
             * Apex determines the Account and authoritative
             * Salesforce PricebookEntry.UnitPrice.
             */
            const selections =
                selected.map(product => {

                    return {
                        productId:
                            product.productId,

                        quantity:
                            Number(product.quantity)
                    };
                });


            /*
             * Convert selections to JSON.
             */
            const selectionsJson =
                JSON.stringify(
                    selections
                );


            console.log(
                'SUBMIT SELECTIONS JSON:',
                selectionsJson
            );


            /*
             * ====================================================
             * CALL APEX
             * ====================================================
             */
            const result =
                await submitOrder({
                    selectionsJson:
                        selectionsJson
                });


            console.log(
                'ORDER SUBMISSION RESULT:',
                result
            );


            /*
             * ====================================================
             * SUCCESS
             * ====================================================
             */
            this.successData = {

                opportunityId:
                    result.opportunityId,

                opportunityName:
                    result.opportunityName,

                opportunityAmount:
                    result.opportunityAmount,

                productCount:
                    result.productCount
            };


        } catch (error) {

            console.error(
                'Dealer order submission error:',
                error
            );


            this.errorMessage =
                this.getErrorMessage(
                    error,
                    'Unable to submit the order.'
                );


        } finally {

            this.isSubmitting = false;
        }
    }


    /*
     * ============================================================
     * PLACE ANOTHER ORDER
     * ============================================================
     */
    handlePlaceAnotherOrder() {

        this.successData = null;

        this.errorMessage = '';

        this.products =
            this.products.map(product => {

                return {
                    ...product,

                    selected:
                        false,

                    quantity:
                        1,

                    quantityDisabled:
                        true,

                    lineTotal:
                        0
                };
            });
    }


    /*
     * ============================================================
     * CLOSE
     * ============================================================
     */
    handleClose() {

        window.history.back();
    }


    /*
     * ============================================================
     * CURRENCY FORMATTER
     * ============================================================
     */
    formatCurrency(value) {

        const amount =
            Number(value || 0);


        return new Intl.NumberFormat(
            'en-IN',
            {
                style: 'currency',
                currency: 'INR',
                minimumFractionDigits: 2
            }
        ).format(amount);
    }


    /*
     * ============================================================
     * ERROR HANDLER
     * ============================================================
     */
    getErrorMessage(
        error,
        fallback
    ) {

        if (
            error &&
            error.body &&
            error.body.message
        ) {

            return error.body.message;
        }


        if (
            error &&
            error.message
        ) {

            return error.message;
        }


        return fallback;
    }
}
