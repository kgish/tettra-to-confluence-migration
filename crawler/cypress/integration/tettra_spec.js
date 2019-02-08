// Pinned items
// #category-show-container > div:nth-child(2) > div.pinned-items-container > div > div.page-list-content > div.flex-auto.mr2 > h4 > a
// Folders
// #category-show-container > div:nth-child(2) > div:nth-child(n) > div.page-list-content > div.flex-auto.mr2 > h4 > a
// Pages
// #category-show-container > div:nth-child(2) > div:nth-child(n) > div.flex-auto > h4 > a

describe('Tettra website', function () {

  function log(message) {
    cy.writeFile(Cypress.env('LOGFILE'), message + "\n", {flag: 'a+'});
  }

  function crawl_next(offset, url) {
    // log(`crawl_next offset='${offset}' url='${url}'`);
    cy.visit(url);
    cy.get('body').then($body => {
        if ($body.find('h4 > a').length !== 0) {
          cy.get('h4 > a').each(($el, index) => {
            cy.wrap($el).each($a => {
              const url = $a.attr('href');
              const matches = url.match(/(folder|page)s\/(.*)$/);
              const type = matches[1];
              const id = matches[2];
              const text = $a.text().replace('|', ' ');
              log(`${offset}-${index}|${type}|${$a.text()}|${id}|${url}`);
              if (type === 'folder') {
                crawl_next(`${offset}-${index}`, url);
              }
            });
          });
        } else {
          // log(`--- Cannot find selector`);
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
        log(`${index}|category|${c.name}|${c.id}|${c.url}`);
        crawl_next(index, c.url);
      });
    })
  }

  it('should be able to crawl all the pages', function () {
    cy.exec(`touch ${Cypress.env('LOGFILE')} && rm ${Cypress.env('LOGFILE')}`);
    cy
      .visit(Cypress.env('TETTRA'))
      .get('h1').contains('Sign in to your team')
      .get('#email').type(Cypress.env('EMAIL'))
      .get('#password').type(Cypress.env('PASSWORD'))
      .get('input[type=submit]').click()
      .url().should('contain', Cypress.env('SPACE'));

    log('offset|type|name|id|url');
    crawl(cy.get('.category-title a'));
  });
});
