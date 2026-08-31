import { LightningElement } from 'lwc';

import image1 from '@salesforce/resourceUrl/voltcoreHeroVisual';
import image2 from '@salesforce/resourceUrl/voltcoreHeroVisual2';
import image3 from '@salesforce/resourceUrl/voltcoreHeroVisual3';
import image4 from '@salesforce/resourceUrl/voltcoreHeroVisual4';
import image5 from '@salesforce/resourceUrl/voltcoreHeroVisual5';

export default class VoltcoreHero extends LightningElement {

    currentSlide = 0;
    slideInterval;
    carouselStarted = false;

    slides = [
        {
            id: 0,
            image: image1,
            alt: 'VoltCore automotive battery'
        },
        {
            id: 1,
            image: image2,
            alt: 'VoltCore battery performance'
        },
        {
            id: 2,
            image: image3,
            alt: 'VoltCore advanced battery technology'
        },
        {
            id: 3,
            image: image4,
            alt: 'VoltCore commercial vehicle battery'
        },
        {
            id: 4,
            image: image5,
            alt: 'VoltCore battery for long journeys'
        }
    ];


    renderedCallback() {

        if (this.carouselStarted) {
            return;
        }

        this.carouselStarted = true;

        this.updateSlides();

        this.startCarousel();
    }


    startCarousel() {

        if (this.slideInterval) {
            return;
        }

        this.slideInterval = setInterval(() => {
            this.nextSlide();
        }, 5000);
    }


    stopCarousel() {

        if (this.slideInterval) {

            clearInterval(this.slideInterval);

            this.slideInterval = null;
        }
    }


    nextSlide() {

        this.currentSlide =
            (this.currentSlide + 1) % this.slides.length;

        this.updateSlides();
    }


    previousSlide() {

        this.currentSlide =
            (this.currentSlide - 1 + this.slides.length) %
            this.slides.length;

        this.updateSlides();
    }


    goToSlide(event) {

        this.currentSlide =
            Number(event.currentTarget.dataset.index);

        this.updateSlides();

        this.stopCarousel();

        this.startCarousel();
    }


    updateSlides() {

        const slideElements =
            this.template.querySelectorAll('.carousel-slide');

        const dotElements =
            this.template.querySelectorAll('.carousel-dot');


        slideElements.forEach((slide, index) => {

            slide.classList.toggle(
                'active',
                index === this.currentSlide
            );

        });


        dotElements.forEach((dot, index) => {

            dot.classList.toggle(
                'active',
                index === this.currentSlide
            );

        });
    }


    disconnectedCallback() {

        this.stopCarousel();
    }

}