# Activate the virtual environment and install requirements
Set-Location "D:\agente-zero"
& "D:\agente-zero\venv\Scripts\Activate.ps1"
pip install -r requirements.txt
Write-Host "Installation completed. Press any key to exit..."
$HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
