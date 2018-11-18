### Automated Code Standards

This project provides a InterSystems IRIS class which utilises server side source control hooks to automatically apply some coding standards when a document is saved.

## Usage
Load the class to target InterSystems IRIS development environment.  Modify the class to inherit from existing source control class.  Use %Studio.SourceControl.Base if there is no server side source control for the environment.
Change the source control class to point to Code Standards using System Management Portal. 

# Options
The code standards class have a number of options which are defined as class parameters.  Modify the values and recompile the class to vary the options.

- Indentation
Format code based on the surrounding structures.

- Code Expansion
Many Object Script commands and variables have short alternative syntax.  When CODEEXPANSION is true these will be converted to use the full text.

- Object Script Case Conversion
COSCASE controls the case which is used for Object Script functions, commands and special variables.

- Object Script Comment
COSCOMMENT controls the comment style used.  Options are ;, //, or #;.

- Object Script White Space
When COSWHITESPACE is true white space will be inserted either side of operators and after each argument.

- SQL Case Conversion
SQLCASE controls the case which is used for SQL keywords and operators.

- Open Whitespace Character
Used as first character for lines beginning with white space.

- Change Get methods 
Objects such as %ResultSet, %CSP.Session, %CSP.Request provide Get methods for backwards compatibility.
There is performance gain by using $get(object.Data("...")) instead of object.Get("...")
When CHANGEGET is true these constructs are automatically applied.

- Change Get Variable
CHANGEGET functionality is restricted to variable matching this pattern.

- Brace Postion
Adjust brace usage to end the line with opening brace and start new lines for closing brace.