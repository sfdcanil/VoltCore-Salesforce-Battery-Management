import { LightningElement } from 'lwc';

export default class VoltCoreProductsCard extends LightningElement {
    title = 'Our Products';

    description =
        'VoltCore offers a range of dependable battery solutions engineered to deliver consistent performance, durability and power.';

    products = [
        'Automotive Batteries',
        'Commercial Batteries',
        'High-Performance Batteries'
    ];
}