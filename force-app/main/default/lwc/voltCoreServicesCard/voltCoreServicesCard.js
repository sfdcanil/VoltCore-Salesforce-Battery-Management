import { LightningElement } from 'lwc';

export default class VoltCoreServicesCard extends LightningElement {
    title = 'Our Services';

    description =
        'From product guidance to after-sales support, VoltCore helps customers and dealers get the most from their battery solutions.';

    services = [
        'Battery Consultation',
        'Dealer Support',
        'Warranty Assistance',
        'After-Sales Service'
    ];
}