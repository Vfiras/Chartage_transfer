from datetime import datetime


def serialize_document(document: dict | None) -> dict | None:
    if document is None:
        return None
    item = dict(document)
    if "_id" in item:
        item["_id"] = str(item["_id"])
    for key, value in list(item.items()):
        if isinstance(value, datetime):
            item[key] = value.isoformat()
    return item
