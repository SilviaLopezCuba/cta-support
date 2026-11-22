package com.mycompany.pro.util;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.Iterator;
import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageOutputStream;

/**
 * Reduce imágenes para los reportes PDF (comprobante de ticket).
 * Solo cambia la copia que va al PDF: el archivo original en ticket_adjuntos queda intacto.
 */
public final class ImagenUtil {

    private ImagenUtil() {
    }

    /**
     * Devuelve la imagen como JPEG con su lado mayor limitado a {@code ladoMax} píxeles.
     * Si la imagen ya es chica la recomprime igual (JPEG calidad 0,75), lo que también reduce PNG pesados.
     * Si el formato no se puede leer (por ejemplo WEBP), devuelve los bytes originales sin cambios.
     *
     * @param entrada contenido de la imagen (puede ser null)
     * @param ladoMax píxeles del lado mayor (700 alcanza para una miniatura impresa de 9 cm a 200 ppp)
     * @return bytes JPEG, los bytes originales si no se pudo procesar, o null si no hay imagen
     */
    public static byte[] miniatura(InputStream entrada, int ladoMax) {
        if (entrada == null) {
            return null;
        }
        byte[] original;
        try {
            original = leerTodo(entrada);
        } catch (Exception e) {
            return null;
        }
        if (original.length == 0) {
            return null;
        }
        try {
            BufferedImage img = ImageIO.read(new java.io.ByteArrayInputStream(original));
            if (img == null) {
                return original;   // formato no soportado por ImageIO: se usa tal cual
            }
            double escala = Math.min(1.0, (double) ladoMax / Math.max(img.getWidth(), img.getHeight()));
            int ancho = Math.max(1, (int) Math.round(img.getWidth() * escala));
            int alto = Math.max(1, (int) Math.round(img.getHeight() * escala));

            // Reducción en pasos de a la mitad: mejor calidad que un solo escalado grande
            BufferedImage actual = img;
            int w = img.getWidth(), h = img.getHeight();
            while (w / 2 >= ancho && h / 2 >= alto) {
                w /= 2;
                h /= 2;
                actual = escalar(actual, w, h);
            }
            BufferedImage fin = escalar(actual, ancho, alto);

            ByteArrayOutputStream salida = new ByteArrayOutputStream();
            Iterator<ImageWriter> escritores = ImageIO.getImageWritersByFormatName("jpeg");
            if (!escritores.hasNext()) {
                return original;
            }
            ImageWriter escritor = escritores.next();
            ImageWriteParam param = escritor.getDefaultWriteParam();
            param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            param.setCompressionQuality(0.75f);
            try (ImageOutputStream ios = ImageIO.createImageOutputStream(salida)) {
                escritor.setOutput(ios);
                escritor.write(null, new IIOImage(fin, null, null), param);
            } finally {
                escritor.dispose();
            }
            byte[] reducida = salida.toByteArray();
            return reducida.length < original.length ? reducida : original;
        } catch (Exception e) {
            return original;
        }
    }

    /** Escala a RGB sobre fondo blanco (las transparencias de PNG quedan blancas, no negras). */
    private static BufferedImage escalar(BufferedImage origen, int ancho, int alto) {
        BufferedImage destino = new BufferedImage(ancho, alto, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = destino.createGraphics();
        try {
            g.setColor(Color.WHITE);
            g.fillRect(0, 0, ancho, alto);
            g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
            g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
            g.drawImage(origen, 0, 0, ancho, alto, null);
        } finally {
            g.dispose();
        }
        return destino;
    }

    private static byte[] leerTodo(InputStream in) throws java.io.IOException {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        byte[] trozo = new byte[16384];
        int n;
        while ((n = in.read(trozo)) != -1) {
            buf.write(trozo, 0, n);
        }
        return buf.toByteArray();
    }
}
