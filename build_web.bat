@echo off
echo ==============================================
echo Compilando Flutter Web para produccion...
echo ==============================================
cd frontend
call flutter build web --release
if %errorlevel% neq 0 (
    echo Error al compilar Flutter Web.
    cd ..
    exit /b %errorlevel%
)
cd ..

echo ==============================================
echo Actualizando archivos estaticos en backend/static...
echo ==============================================
if not exist "backend\static" mkdir "backend\static"
xcopy /E /I /Y "frontend\build\web\*" "backend\static\"

echo ==============================================
echo Exito: Frontend compilado y listo en backend/static!
echo ==============================================
