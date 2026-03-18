====================================================
  SHAKTI GENERAL STORE - INVOICE TOOL
====================================================

FIRST TIME SETUP  (do this once only)
--------------------------------------
1. Double-click:  setup.bat
   - If Python is not installed, it will open the
     download page for you. Install Python and make
     sure to check "Add Python to PATH" during setup.
   - Run setup.bat again after installing Python.
   - Wait for "Setup complete!" message.

2. Place your  credentials.json  file in this folder
   (needed for Google Sheet sync).


STARTING THE APP  (every time)
--------------------------------
Double-click:  run.bat

The app will open in your browser automatically.
To stop the app, close the black terminal window.


ACCESSING FROM YOUR PHONE
--------------------------
1. Your phone must be on the same WiFi as this PC.
2. After starting the app, look for the
   "Mobile Access" address shown in the browser.
3. Type that address in your phone's browser.
   Example:  http://192.168.1.105:5000


INVOICE FILES
--------------
All PDF invoices are saved here:
  invoices\  folder (inside this folder)


TROUBLESHOOTING
----------------
- "Module not found" error  → run setup.bat again
- Google Sheet not syncing  → check credentials.json
  is in this folder and the sheet is named "Invoices"
- Port already in use       → close the previous
  run.bat window and try again
- Can't access from phone   → make sure both devices
  are on the same WiFi network

====================================================
