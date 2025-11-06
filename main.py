"""
Comparatron V1.1 - Flask Version
by Cameron Coward 
fork by RGP
http://www.cameroncoward.com

This is a DIY digital optical comparator that uses a USB microscope mounted to a 
CNC pen plotter to take precise measurements of physical objects through visual means.

Flask version for web compatibility and better UI scaling.
"""

from gui_flask import main as run_flask_gui

def main():
    # Run the Flask GUI
    run_flask_gui()


if __name__ == "__main__":
    main()