*** Settings ***
Library           Selenium2Library

*** Variables ***
${Browser}        chrome
${SiteUrl}        https://youtu.be/HpvZ2HwL4zI
${DashboardTitle}    Linaro Connect BKK16 - Welcome and Introduction - YouTube
${Delay}          10s

*** Test Cases ***
Youtube-Play-Video-Test
    Open Browser to the Youtube Page
    sleep    ${Delay}
    [Teardown]    Close Browser

*** Keywords ***
Open Browser to the Youtube Page
    open browser    ${SiteUrl}    ${Browser}
    Maximize Browser Window
