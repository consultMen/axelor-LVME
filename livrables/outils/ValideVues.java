// LVME : contrôle des vues livrées contre le schéma Axelor 7.4 (object-views.xsd du jar axelor-core) avant de les
// publier. Axelor refuse en entier une vue non conforme (« View … doesn't exist »).
// Usage : java livrables/outils/ValideVues.java <object-views.xsd> livrables/ui/*.xml
import javax.xml.XMLConstants;
import javax.xml.transform.stream.StreamSource;
import javax.xml.validation.*;
import java.io.*;
import java.nio.file.*;

public class ValideVues {
  public static void main(String[] a) throws Exception {
    Schema s = SchemaFactory.newInstance(XMLConstants.W3C_XML_SCHEMA_NS_URI).newSchema(new File(a[0]));
    for (int i = 1; i < a.length; i++) {
      String xml = Files.readString(Path.of(a[i]));
      String doc = "<object-views xmlns=\"http://axelor.com/xml/ns/object-views\">" + xml + "</object-views>";
      try {
        s.newValidator().validate(new StreamSource(new StringReader(doc)));
        System.out.println("OK " + a[i]);
      } catch (Exception e) {
        System.out.println("KO " + a[i] + " : " + e.getMessage());
      }
    }
  }
}
