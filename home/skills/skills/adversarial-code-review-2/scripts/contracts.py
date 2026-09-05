"""One schema source for CLI output constraints and local validation (stdlib only)."""


def obj(**properties):
    return {"type": "object", "properties": properties,
            "required": list(properties), "additionalProperties": False}


def array(items):
    return {"type": "array", "items": items}


def enum(*values):
    return {"type": "string", "enum": list(values)}


STRING = {"type": "string"}
STRINGS = array(STRING)
VERSION = {"type": "integer", "enum": [1]}
LOCATION = obj(revision=STRING, path=STRING,
               startLine={"type": "integer", "minimum": 1},
               endLine={"type": "integer", "minimum": 1})
SIDE = {"anyOf": [obj(kind=enum("present"), location=LOCATION, excerpt=STRING),
                  obj(kind=enum("absent"), reason=enum("added", "deleted"))]}
FINDING = obj(
    id=STRING, title=STRING,
    severity=obj(value=enum("low", "medium", "high"), reasoning=STRING),
    likelihood=obj(value=enum("low", "medium", "high", "unknown"), reasoning=STRING),
    problematicLocation=obj(kind=enum("head", "deletion"), location=LOCATION),
    whatGoesWrong=STRING, before=SIDE, after=SIDE, whyItHappens=STRING,
    supportingLocations=array(LOCATION),
    reproduction=obj(prerequisites=STRINGS, steps=STRINGS, expected=STRING,
                     actual=STRING, basis=enum("observed", "predicted")),
    evidence=STRINGS, limits=STRINGS)
REVIEW = obj(
    schemaVersion=VERSION, runId=STRING, baseSha=STRING, headSha=STRING,
    completeness=enum("complete", "partial"), whatChanged=STRINGS,
    coverage=obj(inspected=STRINGS, checks=array(obj(
        description=STRING, outcome=enum("passed", "failed", "not-run"), details=STRING)),
        limits=STRINGS), findings=array(FINDING))
REF = obj(reviewer=STRING, findingId=STRING)
CONSOLIDATION = obj(
    schemaVersion=VERSION, runId=STRING, whatChanged=STRINGS,
    findings=array(obj(finding=FINDING, sources={**array(REF), "minItems": 1},
                       disagreements=array(obj(reviewer=STRING, explanation=STRING)))),
    excluded=array(obj(source=REF, reason=STRING)), limits=STRINGS)


def validate(value, schema, path="$"):
    """Validate the explicitly supported schema subset used above; reject drift."""
    allowed = {"type", "properties", "required", "additionalProperties", "items",
               "enum", "anyOf", "minimum", "minItems"}
    if set(schema) - allowed:
        raise ValueError(f"Unsupported schema keywords at {path}")
    if "anyOf" in schema:
        for choice in schema["anyOf"]:
            try:
                validate(value, choice, path)
                return
            except ValueError:
                pass
        raise ValueError(f"{path}: no matching variant")
    expected = schema.get("type")
    types = {"object": dict, "array": list, "string": str, "integer": int}
    if expected not in types or type(value) is not types[expected]:
        raise ValueError(f"{path}: expected {expected}")
    if "enum" in schema and value not in schema["enum"]:
        raise ValueError(f"{path}: invalid enum value")
    if expected == "object":
        if set(value) != set(schema["required"]):
            raise ValueError(f"{path}: missing or unexpected fields: "
                             f"{set(value) ^ set(schema['required'])}")
        for key, item in value.items():
            validate(item, schema["properties"][key], f"{path}.{key}")
    elif expected == "array":
        if len(value) < schema.get("minItems", 0):
            raise ValueError(f"{path}: too few items")
        for index, item in enumerate(value):
            validate(item, schema["items"], f"{path}[{index}]")
    elif expected == "integer" and value < schema.get("minimum", value):
        raise ValueError(f"{path}: below minimum")
