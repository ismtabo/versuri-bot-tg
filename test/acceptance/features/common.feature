Feature: Http Server

  Background: 
    Given the HTTP endpoint "[CONF:url]"

  Scenario Outline: Server
     When I send a HTTP "<method>" request
     Then the HTTP status code must be "200"
      And the HTTP response should not be empty
      And the HTTP response should containt the text
          """
          Hello World!
          """
        
    Examples: method: <method>
          | method      |
          | GET         |
          | POST        |
          | PUT         |
          | PATCH       |
          | DELETE      |