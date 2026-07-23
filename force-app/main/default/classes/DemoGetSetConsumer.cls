/**
 * Demo consumer of DemoGetSet. Exists to exercise a cross-developer dependency:
 * this class (Sergio) depends on DemoGetSet (Mario), merged in a separate PR.
 */
public with sharing class DemoGetSetConsumer {
    /**
     * Builds a DemoGetSet from the two inputs and returns them combined as
     * "campoUno - campoDos".
     */
    public static String buildLabel(String uno, String dos) {
        DemoGetSet demo = new DemoGetSet();
        demo.setCampoUno(uno);
        demo.setCampoDos(dos);
        return demo.getCampoUno() + ' - ' + demo.getCampoDos();
    }
}
