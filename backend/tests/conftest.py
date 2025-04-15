import os
import sys

# Añadir el directorio raíz del proyecto al path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, backend_dir) 