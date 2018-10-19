/** Provides classes for assertions. */
private import semmle.code.csharp.frameworks.system.Diagnostics
private import semmle.code.csharp.frameworks.test.VisualStudio
private import semmle.code.csharp.frameworks.System

/** An assertion method. */
abstract class AssertMethod extends Method {
  /** Gets the index of the parameter being asserted. */
  abstract int getAssertionIndex();

  /** Gets the parameter being asserted. */
  final Parameter getAssertionParameter() {
    result = this.getParameter(this.getAssertionIndex())
  }

  /** Gets the exception being thrown if the assertion fails, if any. */
  abstract ExceptionClass getExceptionClass();
}

/** A positive assertion method. */
abstract class AssertTrueMethod extends AssertMethod {
}

/** A negated assertion method. */
abstract class AssertFalseMethod extends AssertMethod {
}

/** A `null` assertion method. */
abstract class AssertNullMethod extends AssertMethod {
}

/** A non-`null` assertion method. */
abstract class AssertNonNullMethod extends AssertMethod {
}

/** An assertion, that is, a call to an assertion method. */
class Assertion extends MethodCall {
  private AssertMethod target;

  Assertion() { this.getTarget() = target }

  /** Gets the assertion method targeted by this assertion. */
  AssertMethod getAssertMethod() { result = target }

  /** Gets the expression that this assertion pertains to. */
  Expr getExpr() {
    result = this.getArgumentForParameter(target.getAssertionParameter())
  }
}

/** A trivially failing assertion, for example `Debug.Assert(false)`. */
class FailingAssertion extends Assertion {
  FailingAssertion() {
    exists(AssertMethod am, Expr e |
      am = this.getAssertMethod() and
      e = this.getExpr() |
      am instanceof AssertTrueMethod and
      e.(BoolLiteral).getBoolValue() = false
      or
      am instanceof AssertFalseMethod and
      e.(BoolLiteral).getBoolValue() = true
    )
  }
}

/**
 * A `System.Diagnostics.Debug` assertion method.
 */
class SystemDiagnosticsDebugAssertTrueMethod extends AssertTrueMethod {
  SystemDiagnosticsDebugAssertTrueMethod() {
    this = any(SystemDiagnosticsDebugClass c).getAssertMethod()
  }

  override int getAssertionIndex() { result = 0 }

  override ExceptionClass getExceptionClass() {
    // A failing assertion generates a message box, see
    // https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.debug.assert
    none()
  }
}

/** A Visual Studio assertion method. */
class VSTestAssertTrueMethod extends AssertTrueMethod {
  VSTestAssertTrueMethod() {
    this = any(VSTestAssertClass c).getIsTrueMethod()
  }

  override int getAssertionIndex() { result = 0 }

  override AssertFailedExceptionClass getExceptionClass() { any() }
}

/** A Visual Studio negated assertion method. */
class VSTestAssertFalseMethod extends AssertFalseMethod {
  VSTestAssertFalseMethod() {
    this = any(VSTestAssertClass c).getIsFalseMethod()
  }

  override int getAssertionIndex() { result = 0 }

  override AssertFailedExceptionClass getExceptionClass() { any() }
}

/** A Visual Studio `null` assertion method. */
class VSTestAssertNullMethod extends AssertNullMethod {
  VSTestAssertNullMethod() {
    this = any(VSTestAssertClass c).getIsNullMethod()
  }

  override int getAssertionIndex() { result = 0 }

  override AssertFailedExceptionClass getExceptionClass() { any() }
}

/** A Visual Studio non-`null` assertion method. */
class VSTestAssertNonNullMethod extends AssertNonNullMethod {
  VSTestAssertNonNullMethod() {
    this = any(VSTestAssertClass c).getIsNotNullMethod()
  }

  override int getAssertionIndex() { result = 0 }

  override AssertFailedExceptionClass getExceptionClass() { any() }
}

/** A method that forwards to another assertion method. */
class ForwarderAssertMethod extends AssertMethod {
  AssertMethod forwardee;
  Parameter p;

  ForwarderAssertMethod() {
    p = this.getAParameter() and
    strictcount(AssignableDefinition def | def.getTarget() = p) = 1 and
    forex(ControlFlowElement body |
      body = this.getABody() |
      exists(Assertion a |
        body = getAnAssertingElement(a) and
        a.getExpr() = p.getAnAccess() and
        forwardee = a.getAssertMethod()
      )
    )
  }

  override int getAssertionIndex() { result = p.getPosition() }

  override ExceptionClass getExceptionClass() {
    result = forwardee.getExceptionClass()
  }
  
  /** Gets the underlying assertion method that is being forwarded to. */
  AssertMethod getUnderlyingAssertMethod() { result = forwardee }
}

private ControlFlowElement getAnAssertingElement(Assertion a) {
  result = a
  or
  result = getAnAssertingStmt(a)
}

private Stmt getAnAssertingStmt(Assertion a) {
  result.(ExprStmt).getExpr() = getAnAssertingElement(a)
  or
  result.(BlockStmt).getFirstStmt() = getAnAssertingElement(a)
}

/** A method that forwards to a positive assertion method. */
class ForwarderAssertTrueMethod extends ForwarderAssertMethod, AssertTrueMethod {
  ForwarderAssertTrueMethod() {
    this.getUnderlyingAssertMethod() instanceof AssertTrueMethod
  }
}

/** A method that forwards to a negated assertion method. */
class ForwarderAssertFalseMethod extends ForwarderAssertMethod, AssertFalseMethod {
  ForwarderAssertFalseMethod() {
    this.getUnderlyingAssertMethod() instanceof AssertFalseMethod
  }
}

/** A method that forwards to a `null` assertion method. */
class ForwarderAssertNullMethod extends ForwarderAssertMethod, AssertNullMethod {
  ForwarderAssertNullMethod() {
    this.getUnderlyingAssertMethod() instanceof AssertNullMethod
  }
}

/** A method that forwards to a non-`null` assertion method. */
class ForwarderAssertNonNullMethod extends ForwarderAssertMethod, AssertNonNullMethod {
  ForwarderAssertNonNullMethod() {
    this.getUnderlyingAssertMethod() instanceof AssertNonNullMethod
  }
}

/** Holds if expression `e` appears in an assertion. */
predicate isExprInAssertion(Expr e) {
  e = any(Assertion a).getExpr().getAChildExpr*()
}
