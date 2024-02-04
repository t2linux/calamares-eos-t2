/* === This file is part of Calamares - <https://calamares.io> ===
 *
 *   SPDX-FileCopyrightText: 2015 Teo Mrnjavac <teo@kde.org>
 *   SPDX-FileCopyrightText: 2018 Adriaan de Groot <groot@kde.org>
 *   SPDX-License-Identifier: GPL-3.0-or-later
 *
 *   Calamares is Free Software: see the License-Identifier above.
 *
 */

import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    function nextSlide() {
        console.log("Process is running in the background...");
        presentation.goToNextSlide();
    }

    Timer {
        id: advanceTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
           anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            border.width: 0
            color: "#2a2e32"
            Image {
                id: slide_trust
                source: "slide-trust.png"
                fillMode: Image.PreserveAspectFit
                anchors.fill: parent
            }
        }
    }

    Slide {
           anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            border.width: 0
            color: "#2a2e32"
            Image {
                id: slide_welcome_app
                source: "slide-welcome-app.png"
                fillMode: Image.PreserveAspectFit
                anchors.fill: parent
            }
        }
    }

    Slide {
            anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            border.width: 0
            color: "#2a2e32"
            Image {
                id: slide_discover
                source: "slide-discover.png"
                fillMode: Image.PreserveAspectFit
                anchors.fill: parent
            }
        }
    }

    Slide {
           anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            border.width: 0
            color: "#2a2e32"
            Image {
                id: slide_forum
                source: "slide-forum.png"
                fillMode: Image.PreserveAspectFit
                anchors.fill: parent
            }
        }
    }

    function onActivate() {
        console.log("QML Component (default slideshow) activated");
        presentation.currentSlide = 0;
    }

    function onLeave() {
        console.log("QML Component (default slideshow) deactivated");
    }
}
