

function SearchForBugs( words, searchRadio ) {
    var word = new String(words).split(/[\s]+/);
    var searchLong = true;

    if ( searchRadio[0].checked )
        searchLong = false;

    if ( word.length == 1 && word[0] == "" )
        return;

    var searchURL = "http://bugzilla.mozilla.org/buglist.cgi?"+
        "bug_status=NEW&bug_status=ASSIGNED&bug_status=REOPENED";

    var chart = 0;
    var and = 0;
    var or = 0;

    for ( var i = 0; i < word.length; i++, chart++ ) {
        var expr = chart+"-"+and+"-"+or;

        searchURL += "&field" +expr+ "=short_desc" +
                    "&type" + expr +"=substring"+
                    "&value"+ expr +"="+ word[i];

        if ( searchLong ) {
            or++;

            expr = chart +"-"+and+"-"+or;
            searchURL += "&field" +expr+ "=longdesc" +
                         "&type"  +expr+ "=substring" +
                         "&value" +expr+ "=" + word[i];
        }

        if ( word[i].match(/http/)) {
            or++;
            expr = chart +"-"+and+"-"+or;
            searchURL += "&field" +expr+ "=bug_file_loc" +
                         "&type"  +expr+ "=substring" +
                         "&value" +expr+ "=" + word[i];

        }
        or = 0;
    }

    searchURL += "&cmdtype=doit";

    window.open( searchURL, "other" );
    didSearch = true;
}

function SeeBugsInComponent(aForm) {
    if ( aForm.Component.selectedIndex >= 0 ) {
        var component = escape(aForm.Component[aForm.Component.selectedIndex].value);
    var searchURL = "http://bugzilla.mozilla.org/buglist.cgi?"+
        "bug_status=NEW&bug_status=ASSIGNED&bug_status=REOPENED"+
        "&component="+component+"&cmdtype=doit";

        window.open( searchURL, "other" );
    }
}
function OpenEnterBugPage() {
    CheckValues(document.BugInfoForm);
    if ( readyToFile ) {
        if ( URL ) {
            window.open( URL, "other" );
        }
    }
    return;
}
function CheckValues( aForm ) {
    var message = [];
    var okay = true;

    if ( didSearch == false ) {
        message[message.length] = "Please go back to Step 2, and search for your bug.\n"+
            "Please try not to file a bug we already know about.\n"
    }


    if ( aForm.Component.selectedIndex < 1 ) {
        message[message.length] = "Component:  Please select a Component.";
        okay = false;
    }

    if ( (aForm.Summary.value.split(/[\s]+/)).length < 3 ) {
        message[message.length] = "Summary:  Please provide a more descriptive Summary.";
        okay = false;
    }
    /*
    if ( aForm.Description.value == defaultDescriptionValue ||
        (aForm.Description.value.split(/[\s]+)/)).length < 5 ) {
        message[message.length] = "Please provide a more information in your Description.";
        okay = false;
    }
    */
    switch( aForm.Reproducible.selectedIndex ) {
        case 0:
            message[message.length] = "Reproducibility:  Please say how often you can reproduce the problem.";
            okay = false;
            break;
        case 1: case 2:

            if ( aForm.ReproduceSteps.value.split(/[\s]+/).join() == "1.,2.,3." ||
                aForm.ReproduceSteps.value == ""  ) {
                message[message.length] = "Steps to Reproduce: Please let us know how to reproduce the problem.";
                okay = false;
            }
            break;
        default:
            break;
    }
    // Let people file a bug even if they don't have a valid buildID, but
    // nag them about it.
    if ( aForm.BuildID.value.length < 2 ) {
        message[message.length] = "BuildID:  You must provide a BuildID.";
    } else if ( ! aForm.BuildID.value.match(/[0-9]{10}/) ) {
        message[message.length] = "BuildID: The BuildID you entered is invalid."
    } else if ( !aForm.BuildID.value.match(/2000[0-9]{6}/) ) {
        message[message.length] = "BuildID: The build you are using is way ancient. "+
            "Please download a newer build and try to reproduce your bug.";
    }

    bug = { Product:    aForm.Product[aForm.Product.selectedIndex].value,
            Component:  aForm.Component[aForm.Component.selectedIndex].value,
            Platform:   aForm.Platform[aForm.Platform.selectedIndex].value,
            OpSys:      aForm.OpSys[aForm.OpSys.selectedIndex].value,
            BuildID:    aForm.BuildID.value,
            Severity:   "normal",
            Priority:   "P3",
            URL:        aForm.URL.value,
            Summary:    aForm.Summary.value,
            Description:aForm.Description.value,
            Reproducible:aForm.Reproducible[aForm.Reproducible.selectedIndex].value }

    if ( aForm.ReproduceSteps.value == defaultReproduceSteps ||
            aForm.ReproduceSteps.value.split(/[\s]+/).join() == "1.,2.,3." )
        {
            bug.ReproduceSteps = "";
        } else {
            bug.ReproduceSteps = "\nSteps to Reproduce:\n" +
                aForm.ReproduceSteps.value;
        }

    if ( aForm.ActualResults.value.match(/[\s]+/) !=  aForm.ActualResults.value &&
        aForm.ActualResults.value != "" ) {
        bug.ActualResults = "\n\nActual Results:  " + aForm.ActualResults.value;
    } else {
        bug.ActualResults = "";
    }

    if ( aForm.ExpectedResults.value.match(/[\s]+/) != aForm.ExpectedResults.value &&
        aForm.ExpectedResults.value    != "" ) {
        bug.ExpectedResults = "\n\nExpected Results:  " +aForm.ExpectedResults.value;
    } else {
        bug.ExpectedResults = "";
    }

    if ( aForm.AdditionalInfo.value.match(/[\s]+/) != aForm.AdditionalInfo.value &&
        aForm.AdditionalInfo.value != "" ) {
        bug.AdditionalInfo = "\n\n" + aForm.AdditionalInfo.value +"\n";
    } else {
        bug.AdditionalInfo = "";
    }

    // Construct the long description.  First, add interesting headers, then
    // add any non-Bugzilla related fields.
    var long_desc =
      "From Bugzilla Helper:\n"+
      "User-Agent: " + navigator.userAgent +"\n"+
      "BuildID:    "+ bug.BuildID +
      "\n\n"+bug.Description +
      "\n\nReproducible: " + bug.Reproducible + bug.ReproduceSteps+
      bug.ActualResults +
      bug.ExpectedResults +
      bug.AdditionalInfo ;

    // Create the Bugzilla URL
    var url_args =
    "product="       + escape(bug.Product)  +
    "&component="    + escape(bug.Component)+
//    "&version="      + escape(bug.Version)  +
    "&rep_platform=" + escape(bug.Platform) +
    "&op_sys="       + escape(bug.OpSys)    +
    "&priority="     + escape(bug.Priority) +
    "&bug_severity="   + escape(bug.Severity) +
    "&bug_file_loc="   + escape(bug.URL)      +
    "&short_desc="     + ConvertPlus(escape(bug.Summary))
    + "&comment="      + ConvertPlus(escape(long_desc))
    ;

    if ( navigator.userAgent.match( /5\.0/ ) && !navigator.userAgent.match(/compatible/) ) {
        dump( "Going to try to open this url:\n " +url + url_args +"\n" );
    }

    if (okay) {
        readyToFile = true;
        URL = url + url_args;

    } else {
        var alertMessage = "";
        for ( var i = 0; i < message.length; i++ ) alertMessage += message[i]+"\n";

        alert( "Your bug information is incomplete.  "+
            "Please address the following issues:\n\n"+
            alertMessage );
    }
}

function ConvertPlus( aString ) {
    if ( aString.indexOf( "+" ) == -1 )
        return aString;

    return aString.replace( /[\+]{1}/g, "%2B" );

}

var URL;
var url = "http://bugzilla.mozilla.org/enter_bug.cgi?";
var defaultDescriptionValue = "";
var defaultReproduceSteps = "1.\n2.\n3.";
var defaultBrowserComponents = '<SELECT NAME=component SIZE=5><option value="Choose One..."><OPTION VALUE="ActiveX Wrapper">ActiveX Wrapper<OPTION VALUE="Autofill">Autofill<OPTION VALUE="Bookmarks">Bookmarks<OPTION VALUE="Browser-General">Browser-General<OPTION VALUE="Build Config">Build Config<OPTION VALUE="CAPS">CAPS<OPTION VALUE="chatzilla">chatzilla<OPTION VALUE="Compositor">Compositor<OPTION VALUE="Cookies">Cookies<OPTION VALUE="DOM Level 0">DOM Level 0<OPTION VALUE="DOM Level 1">DOM Level 1<OPTION VALUE="DOM Level 2">DOM Level 2<OPTION VALUE="DOM Viewer">DOM Viewer<OPTION VALUE="Editor">Editor<OPTION VALUE="Embedding APIs">Embedding APIs<OPTION VALUE="Embedding: Docshell">Embedding: Docshell<OPTION VALUE="Event Handling">Event Handling<OPTION VALUE="Form Submission">Form Submission<OPTION VALUE="GTK Embedding Widget">GTK Embedding Widget<OPTION VALUE="Help">Help<OPTION VALUE="History">History<OPTION VALUE="HTML Dialogs">HTML Dialogs<OPTION VALUE="HTML Element">HTML Element<OPTION VALUE="HTML Form Controls">HTML Form Controls<OPTION VALUE="HTMLFrames">HTMLFrames<OPTION VALUE="HTMLTables">HTMLTables<OPTION VALUE="Image Conversion Library">Image Conversion Library<OPTION VALUE="ImageLib">ImageLib<OPTION VALUE="Installer">Installer<OPTION VALUE="Installer: XPI Packages">Installer: XPI Packages<OPTION VALUE="Installer: XPInstall Engine">Installer: XPInstall Engine<OPTION VALUE="Internationalization">Internationalization<OPTION VALUE="Java APIs for DOM">Java APIs for DOM<OPTION VALUE="Java APIs to WebShell">Java APIs to WebShell<OPTION VALUE="Java FrontEnd">Java FrontEnd<OPTION VALUE="Java to XPCOM Bridge">Java to XPCOM Bridge<OPTION VALUE="Java-Implemented Plugins">Java-Implemented Plugins<OPTION VALUE="JavaScript Debugger">JavaScript Debugger<OPTION VALUE="Javascript Engine">Javascript Engine<OPTION VALUE="Layout">Layout<OPTION VALUE="libPref">libPref<OPTION VALUE="Live Connect">Live Connect<OPTION VALUE="Localization">Localization<OPTION VALUE="MathML">MathML<OPTION VALUE="Networking">Networking<OPTION VALUE="Networking: Cache">Networking: Cache<OPTION VALUE="OJI">OJI<OPTION VALUE="other">other<OPTION VALUE="Output">Output<OPTION VALUE="Parser">Parser<OPTION VALUE="Password Cache">Password Cache<OPTION VALUE="PICS">PICS<OPTION VALUE="Plug-ins">Plug-ins<OPTION VALUE="Pref UI">Pref UI<OPTION VALUE="Printing">Printing<OPTION VALUE="Profile Manager BackEnd">Profile Manager BackEnd<OPTION VALUE="Profile Manager FrontEnd">Profile Manager FrontEnd<OPTION VALUE="Profile Migration">Profile Migration<OPTION VALUE="Progress Window">Progress Window<OPTION VALUE="RDF">RDF<OPTION VALUE="Search">Search<OPTION VALUE="Security">Security<OPTION VALUE="Selection">Selection<OPTION VALUE="Sidebar">Sidebar<OPTION VALUE="Single Signon">Single Signon<OPTION VALUE="Style System">Style System<OPTION VALUE="SVG">SVG<OPTION VALUE="Threading">Threading<OPTION VALUE="UE/UI">UE/UI<OPTION VALUE="Viewer App">Viewer App<OPTION VALUE="Views">Views<OPTION VALUE="XML">XML<OPTION VALUE="XP File Handling">XP File Handling<OPTION VALUE="XP Miscellany">XP Miscellany<OPTION VALUE="XP Toolkit/Widgets">XP Toolkit/Widgets<OPTION VALUE="XP Toolkit/Widgets: Menus">XP Toolkit/Widgets: Menus<OPTION VALUE="XP Toolkit/Widgets: Trees">XP Toolkit/Widgets: Trees<OPTION VALUE="XP Toolkit/Widgets: XBL">XP Toolkit/Widgets: XBL<OPTION VALUE="XP Toolkit/Widgets: XUL">XP Toolkit/Widgets: XUL<OPTION VALUE="XP Utilities">XP Utilities<OPTION VALUE="XPApps">XPApps<OPTION VALUE="XPCOM">XPCOM<OPTION VALUE="XPCOM Registry">XPCOM Registry<OPTION VALUE="XPConnect">XPConnect<OPTION VALUE="xpidl">xpidl<OPTION VALUE="Y2k">Y2k<OPTION VALUE="Zlib">Zlib</SELECT>'
var defaultMailNewsComponents = '<SELECT NAME=component SIZE=5><option value="Choose One..."><OPTION VALUE="Account Manager">Account Manager<OPTION VALUE="Address Book">Address Book<OPTION VALUE="Back End">Back End<OPTION VALUE="Composition">Composition<OPTION VALUE="Database">Database<OPTION VALUE="Front End">Front End<OPTION VALUE="Internationalization">Internationalization<OPTION VALUE="Localization">Localization<OPTION VALUE="MIME">MIME<OPTION VALUE="Networking-Mail">Networking-Mail<OPTION VALUE="Printing">Printing<OPTION VALUE="Profile Migration">Profile Migration<OPTION VALUE="Security">Security<OPTION VALUE="XPConnect">XPConnect</SELECT>'
var readyToFile = false;
var didSearch = false;

function PrefillBugInfoForm() {
    aForm = document.forms.BugInfoForm;
    aForm.Description.value = defaultDescriptionValue;
    aForm.ReproduceSteps.value= defaultReproduceSteps;

    // try to get app name/version

    var userAgent = navigator.userAgent;
    var platform;
    var op_sys;

    if ( userAgent.match(/Win/)) {
        platform = "PC";
        if ( userAgent.match( /Win.*16/ )) {
            op_sys = "Windows 3.1";
        } else if (userAgent.match( "32bit") || userAgent.match( /Win.*NT/)) {
            op_sys = "Windows NT";
        } else if ( userAgent.match( /Win.*95/ )) {
            op_sys = "Windows 95";
        } else if ( userAgent.match( /Win.*98/ )) {
            op_sys = "Windows 98";
        }
    } else if ( userAgent.match( "Mac" )) {
        platform = "Macintosh";
        if ( userAgent.match( "PPC" )) {
            op_sys = "Mac System 8.5";
        } else if ( userAgent.match( "68K" )) {
            op_sys = "Mac System 8.5";
        }
    } else if ( userAgent.match( "Linux" )) {
        op_sys = "Linux";
        if ( userAgent.match( "86"  )) {
            platform = "PC";
        } else {
            platforn = "DEC";
        }
    } else if ( userAgent.match( "OSF" )) {
        platform = "DEC";
        op_sys = "OSF/1";
    } else if ( userAgent.match( "IRIX" )) {
        platform = "SGI";
        op_sys = "IRIX";
    } else if ( userAgent.match( "HP" )) {
        platform = "HP";
    } else if ( userAgent.match( /SunOS|Solaris/ )) {
        platform = "Sun";
        if ( userAgent.match ( /SunOS 5/ )) {
            op_sys = "Solaris";
        } else {
            op_sys = "SunOS";
        }
    } else if ( userAgent.match( "BSD" )) {
        platform = "BSDI";
        op_sys = "BSDI";
    }

    var s = "";
    var options = aForm.OpSys.options;
    for ( p in options ) { s += p +":"+options[p]+"\n"; }


    if ( platform ) {
        for ( var i = 0; i < aForm.Platform.options.length; i++ ) {
            if ( aForm.Platform.options[i].value == platform ) {
                aForm.Platform.selectedIndex = i;
            }
        }
    }
    if ( op_sys ) {
        for ( var i = 0; i < aForm.OpSys.options.length; i++ ) {
            if ( aForm.OpSys.options[i].value == op_sys ) {
                aForm.OpSys.selectedIndex = i;
            }
        }
    }

}

function ReplaceComponentSelect( aForm, anArray, aName ) {
    for ( var i = 0; i < anArray.length; i++ ) {
        aForm.Component.options[i].text  = anArray[i];
        aForm.Component.options[i].value = anArray[i];
    }
    if ( aForm.Component.length > anArray.length ) {
        for ( ; i < aForm.Component.length; i++ ) {
            aForm.Component.options[i].text = "";
            aForm.Component.options[i].value = "";
        }
    }

}

function UpdateComponentList(aForm) {
    var product = aForm.Product.selectedIndex;

    switch ( product ) {
        case 0:
            ReplaceComponentSelect( aForm, BrowserComponentArray, "Browser" );
            break;
        case 1:
            ReplaceComponentSelect( aForm, MailNewsComponentArray, "MailNews" );
            break;

        case 2:
            ReplaceComponentSelect( aForm, DocumentationComponentArray,"Documentation");
            break;
    }
}

var currentComponentArray = "Browser";

var MailNewsComponentArray = [
        "Choose One...",
        "Account Manager", "Address Book", "Back End", "Composition", "Database",
        "Front End", "Internationalization", "Localization", "MIME", "Networking-Mail",
        "Printing", "Profile Migration", "Security", "XPConnect"
        ];

var BrowserComponentArray = [
    "Choose One...",

    "ActiveX Wrapper", "Autofill", "Bookmarks", "Browser-General","Build Config",
    "chatzilla","Compositor","Cookies","DOM Level 0","DOM Level 1","DOM Level 2",
    "DOM to Text Conversion","DOM Viewer","Editor","Embedding APIs","Embedding: Docshell",
    "Event Handling","Form Submission","GTK Embedding Widget","Help","History",
    "HTML Element","HTML Form Controls","HTMLFrames","HTMLTables","Image Conversion Library",
    "ImageLib","Installer","Installer: XPI Packages","Installer: XPInstall Engine",
    "Internationalization","Java APIs for DOM","Java APIs to WebShell","Java FrontEnd",
    "Java to XPCOM Bridge","Java-Implemented Plugins","JavaScript Debugger",
    "Javascript Engine","Layout","Live Connect","Localization","MathML",
    "MozillaTranslator","Networking","Networking: Cache","OJI","other",
    "Parser","PICS","Plug-ins","Preferences","Preferences: Backend",
    "Printing","Profile Manager BackEnd","Profile Manager FrontEnd","Profile Migration",
    "Progress Window","RDF","Search","Security: CAPS","Security: Crypto",
    "Security: General","Selection","Sidebar","Single Signon","Style System",
    "SVG","Threading","User Interface: Design Feedback","Viewer App","Views",
    "XML","XP Miscellany","XP Toolkit/Widgets","XP Toolkit/Widgets: Menus",
    "XP Toolkit/Widgets: Trees","XP Toolkit/Widgets: XBL","XP Toolkit/Widgets: XUL",
    "XP Utilities","XPApps","XPCOM","XPCOM Registry","XPConnect","xpidl","Y2k"]

var DocumentationComponentArray = [
    "Choose One...",
    "Mozilla Developer", "User", "Web Developer" ];

