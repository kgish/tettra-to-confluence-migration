describe('Crawl the Tettra website', function () {
    it('should be redirected to the login page', function () {
        cy
            .visit(Cypress.env('TETTRA'))
            .get('h1').contains('Sign in to your team')
            .get('#email').type(Cypress.env('EMAIL'))
            .get('#password').type(Cypress.env('PASSWORD'))
            .get('input[type=submit]').click()
            .url().should('contain', Cypress.env('SPACE'))
            .get('.category-title a').each($el => {
                cy.log($el.text());
                cy.log($el.attr('href'));
            })
    })
});