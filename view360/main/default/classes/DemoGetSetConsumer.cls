/**
 * Demo consumer of DemoGetSet. Exists to exercise a cross-developer dependency:
 * this class (Sergio) depends on DemoGetSet (Mario), merged in a separate PR.
 *
 * The separator between the two fields is a single dash surrounded by spaces.
 */
public with sharing class DemoGetSetConsumer {
    /**
     * Builds a DemoGetSet from the two inputs and returns them combined.
     *
     * @param uno value stored in campoUno
     * @param dos value stored in campoDos
     * @return the two fields combined as "campoUno - campoDos"
     */
    public static String buildLabel(String uno, String dos) {
        DemoGetSet demo = new DemoGetSet();
        demo.setCampoUno(uno);
        demo.setCampoDos(dos);
        return demo.getCampoUno() + ' - ' + demo.getCampoDos();
    }
}
