# Usa una imagen base de Python
FROM python:3.13-slim

# Establece el directorio de trabajo
WORKDIR /app

# Copia los archivos de requirements.txt e instálalos
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia el resto del código al contenedor
COPY . .


# Expón el puerto que usa Cloud Run
EXPOSE 8080

# (opción A – recomendada) usa shell para expandir ${PORT} y arranca uvicorn
CMD sh -c "alembic upgrade head || echo 'Alembic failed, continuing...' && exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"

# Expone el puerto en el que la aplicación escucha
#EXPOSE 8000

# Comando para ejecutar migraciones y precargar datos antes de iniciar la app
#CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]

#CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
