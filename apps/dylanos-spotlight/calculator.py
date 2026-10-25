"""Small, bounded arithmetic evaluator used by Spotlight's inline calculator."""
import ast
import math
import operator

MAX_EXPRESSION_LENGTH = 128
MAX_AST_NODES = 48
MAX_MAGNITUDE = 1e100
MAX_EXPONENT = 100

_BINARY = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.FloorDiv: operator.floordiv,
    ast.Mod: operator.mod,
    ast.Pow: operator.pow,
}
_UNARY = {ast.UAdd: operator.pos, ast.USub: operator.neg}


def safe_calculate(expression):
    """Evaluate arithmetic only, rejecting costly or out-of-range expressions."""
    if not isinstance(expression, str) or not expression.strip():
        raise ValueError("Expresión vacía")
    if len(expression) > MAX_EXPRESSION_LENGTH:
        raise ValueError("La expresión es demasiado larga")
    tree = ast.parse(expression.replace("^", "**"), mode="eval")
    nodes = list(ast.walk(tree))
    if len(nodes) > MAX_AST_NODES:
        raise ValueError("La expresión es demasiado compleja")

    def evaluate(node):
        if isinstance(node, ast.Expression):
            return evaluate(node.body)
        if isinstance(node, ast.Constant) and type(node.value) in (int, float):
            value = node.value
        elif isinstance(node, ast.UnaryOp) and type(node.op) in _UNARY:
            value = _UNARY[type(node.op)](evaluate(node.operand))
        elif isinstance(node, ast.BinOp) and type(node.op) in _BINARY:
            left = evaluate(node.left)
            right = evaluate(node.right)
            if isinstance(node.op, ast.Pow) and abs(right) > MAX_EXPONENT:
                raise ValueError("El exponente máximo es 100")
            value = _BINARY[type(node.op)](left, right)
        else:
            raise ValueError("Solo se permiten operaciones aritméticas")

        if isinstance(value, complex) or not math.isfinite(value) or abs(value) > MAX_MAGNITUDE:
            raise ValueError("El resultado está fuera del rango permitido")
        return value

    return evaluate(tree)
