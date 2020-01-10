/// <reference types="Cypress" />

context('App', () => {
  beforeEach(() => {
    cy.visit('/')
  })

  it('should load', () => {
    cy.location('pathname')
      .should('be', '/')

    cy.get('h1').contains('Welcome to codebuild-cypress-demo')
  })
})