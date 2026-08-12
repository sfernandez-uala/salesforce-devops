/**
 * Clase de demostración con dos campos y sus accesores get/set.
 */
public with sharing class DemoGetSet {
    private String campoUno;
    private String campoDos;

    /**
     * Devuelve el valor de campoUno.
     */
    public String getCampoUno() {
        return campoUno;
    }

    /**
     * Establece el valor de campoUno.
     */
    public void setCampoUno(String campoUno) {
        this.campoUno = campoUno;
    }

    /**
     * Devuelve el valor de campoDos.
     */
    public String getCampoDos() {
        return campoDos;
    }

    /**
     * Establece el valor de campoDos.
     */
    public void setCampoDos(String campoDos) {
        this.campoDos = campoDos;
    }
}
