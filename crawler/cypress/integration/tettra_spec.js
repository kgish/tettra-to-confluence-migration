describe('Crawl the Tettra website', function () {

    function log(message) {
        cy.writeFile('crawler.log', message + "\n", {flag: 'a+'});
    }

// #category-show-container > div:nth-child(2) > div.pinned-items-container > div > div.page-list-content > div.flex-auto.mr2 > h4 > a
// #category-show-container > div:nth-child(2) > div:nth-child(n) > div.page-list-content > div.flex-auto.mr2 > h4 > a
// #category-show-container > div:nth-child(2) > div:nth-child(n) > div.flex-auto > h4 > a
    function crawl_next(offset, url) {
        log(`crawl_next offset='${offset}' url='${url}'`);
        cy.visit(url);
        cy.get('body').then($body => {
                if ($body.find('#category-show-container > div:nth-child(2)').length !== 0) {
                    cy.get('#category-show-container > div:nth-child(2)').each($el => {
                        cy.wrap($el).get('h4 > a').each(($a, index) => {
                            const url = $a.attr('href');
                            const matches = url.match(/(folder|page)s\/(.*)$/);
                            const type = matches[1];
                            const id = matches[2];
                            log(`offset='${offset}' index='${index}' type='${type}' name='${$a.text()}' id='${id}' url='${url}'`);
                            crawl_next(`${offset}-${index}`, url);
                        });
                    });
                } else {
                    log(`--- Cannot find selector`);
                }
            }
        );
    }

    function crawl(c) {
        let categories = [];
        c.each($el => {
            const url = $el.attr('href');
            categories.push({
                name: $el.text(),
                id: url.match(/\/([^/]+)$/)[1],
                url: url
            });
        }).then(() => {
            categories.forEach((c, index) => {
                log(`index='${index}' type='category' name='${c.name}' id='${c.id}' url='${c.url}'`);
                if (index === 0) {
                    crawl_next(index, c.url);
                }
            });
        })

    }

    it('should be redirected to the login page', function () {
        cy.exec('touch crawler.log && rm crawler.log');
        cy
            .visit(Cypress.env('TETTRA'))
            .get('h1').contains('Sign in to your team')
            .get('#email').type(Cypress.env('EMAIL'))
            .get('#password').type(Cypress.env('PASSWORD'))
            .get('input[type=submit]').click()
            .url().should('contain', Cypress.env('SPACE'));

        crawl(cy.get('.category-title a'));
    })
});