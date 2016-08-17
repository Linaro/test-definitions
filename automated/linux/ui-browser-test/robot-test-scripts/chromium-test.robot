*** Settings ***
Library  Selenium2Library

*** Variables ***

*** Test Cases ***
Open-Chromium-Browser-Test
    [Documentation]  Test program to open and close chromium browser
    [Tags]  smoketest
    Open Browser  http://www.linaro.org  chrome
    sleep    5s
    Close Browser

*** Keywords ***
