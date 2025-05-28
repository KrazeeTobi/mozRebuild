try {
	supermario();
} catch (e) {
	print("JS Exception caught: " + e);
}

try {
	java.lang.Class.forName("blah");
} catch (e) {
	print("Java Exception caught: " + e);
}

try {
	str = Packages.Test.doit(this, "throw 'foo'", true);
	print(str);
} catch (e) {
	print("Wrapped Exception caught: " + e);
}
