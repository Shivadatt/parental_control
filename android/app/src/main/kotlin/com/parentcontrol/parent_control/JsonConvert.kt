package com.parentcontrol.parent_control

import org.json.JSONArray
import org.json.JSONObject

/** Convert between Flutter platform-channel values and org.json containers. */
object JsonConvert {
    fun toJson(value: Any?): Any? = when (value) {
        null -> JSONObject.NULL
        is JSONObject, is JSONArray -> value
        is Map<*, *> -> {
            val json = JSONObject()
            for ((key, item) in value) {
                if (key == null) continue
                json.put(key.toString(), toJson(item))
            }
            json
        }
        is Iterable<*> -> {
            val array = JSONArray()
            for (item in value) {
                array.put(toJson(item))
            }
            array
        }
        is Array<*> -> {
            val array = JSONArray()
            for (item in value) {
                array.put(toJson(item))
            }
            array
        }
        is Int, is Long, is Double, is Float, is Boolean, is String -> value
        else -> value.toString()
    }

    fun toJsonObject(value: Any?): JSONObject? {
        val converted = toJson(value)
        return converted as? JSONObject
    }

    fun toMap(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> {
            val map = LinkedHashMap<String, Any?>()
            val keys = value.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                map[key] = toMap(value.opt(key))
            }
            map
        }
        is JSONArray -> {
            val list = ArrayList<Any?>(value.length())
            for (index in 0 until value.length()) {
                list.add(toMap(value.opt(index)))
            }
            list
        }
        else -> value
    }

    fun optStringList(array: JSONArray?): List<String> {
        if (array == null) return emptyList()
        val values = ArrayList<String>(array.length())
        for (index in 0 until array.length()) {
            val raw = array.opt(index)
            if (raw == null || raw == JSONObject.NULL) continue
            val text = raw.toString().trim()
            if (text.isNotEmpty()) values.add(text)
        }
        return values
    }
}
