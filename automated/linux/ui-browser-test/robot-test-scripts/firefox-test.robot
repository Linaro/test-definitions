*** Settings ***
Library  Selenium2Library

*** Variables ***

*** Test Cases ***
Open-Firefox-Browser-Test
    [Documentation]  Test program to open and close firefox browser
    [Tags]  smoketest
    Open Browser  http://www.linaro.org  firefox
    sleep    5s
    Close Browser

*** Keywords ***
