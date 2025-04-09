from OpenSSL import crypto
import os

def generate_self_signed_cert():
    """
    Genera un certificado SSL autofirmado para desarrollo.
    Crea dos archivos: 'cert.pem' (certificado) y 'key.pem' (clave privada).
    """
    # Generar par de claves
    k = crypto.PKey()
    k.generate_key(crypto.TYPE_RSA, 2048)

    # Crear certificado
    cert = crypto.X509()
    cert.get_subject().C = "ES"
    cert.get_subject().ST = "Estado"
    cert.get_subject().L = "Ciudad"
    cert.get_subject().O = "eduCode.AI"
    cert.get_subject().OU = "Development"
    cert.get_subject().CN = "localhost"
    cert.set_serial_number(1000)
    cert.gmtime_adj_notBefore(0)
    cert.gmtime_adj_notAfter(365*24*60*60)  # Válido por un año
    cert.set_issuer(cert.get_subject())
    cert.set_pubkey(k)
    cert.sign(k, 'sha256')

    # Guardar certificado
    with open("cert.pem", "wb") as f:
        f.write(crypto.dump_certificate(crypto.FILETYPE_PEM, cert))
    
    # Guardar clave privada
    with open("key.pem", "wb") as f:
        f.write(crypto.dump_privatekey(crypto.FILETYPE_PEM, k))
    
    print("Certificados SSL generados correctamente:")
    print("- cert.pem: Certificado")
    print("- key.pem: Clave privada")

if __name__ == "__main__":
    generate_self_signed_cert()