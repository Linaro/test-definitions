*** Settings ***
Library  Selenium2Library

*** Variables ***

*** Test Cases ***
Open-Google-Chrome-Browser-Test
    [Documentation]  Test program to open and close google-chrome browser
    [Tags]  smoketest
    Open Browser  http://www.linaro.org  chrome
    sleep    5s
    Close Browser

*** Keywords ***
