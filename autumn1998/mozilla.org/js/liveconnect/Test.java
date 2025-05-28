import netscape.javascript.JSObject;
import netscape.javascript.JSException;

public class Test {

    public static Object doit(JSObject obj, String code, boolean catchit) {
	if (catchit) {
	    try {
		obj.eval(code);
	    } catch (JSException e) {
                if (e.getWrappedException()==null)
			return e;
		return e.getWrappedException(); 
	    }
	} else {
	    obj.eval(code);
	}
	return null;
    }
}
