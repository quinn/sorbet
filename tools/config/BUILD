package(default_visibility = ["//visibility:public"])

config_setting(
    name = "darwin",
    values = {"host_cpu": "darwin"},
)

config_setting(
    name = "linux",
    values = {"host_cpu": "k8"},
)

config_setting(
    name = "opt",
    values = {"compilation_mode": "opt"},
)

config_setting(
    name = "dbg",
    values = {"compilation_mode": "dbg"},
)

config_setting(
    name = "fastbuild",
    values = {"compilation_mode": "fastbuild"},
)

config_setting(
    name = "sanitized",
    values = {
        "define": "unsanitized=false",
    },
)

config_setting(
    name = "webasm",
    values = {
        "cpu": "webasm",
    },
)

config_setting(
    name = "linkshared",
    values = {
        "define": "linkshared=true",
    },
)

config_setting(
    name = "darwindbg",
    values = {
        "host_cpu": "darwin",
        "compilation_mode": "dbg",
    },
)

config_setting(
    name = "release",
    values = {
        "define": "release=true",
    },
)
