"""Analysis-time assertions for the publishable npm_package target."""

load("@aspect_rules_js//npm:providers.bzl", "NpmPackageInfo")
load("@aspect_rules_js//js:providers.bzl", "JsInfo")

def _producer_package_metadata_impl(ctx):
    package_target = ctx.attr.package
    compiled_target = ctx.attr.compiled

    if NpmPackageInfo not in package_target:
        fail("{} does not provide NpmPackageInfo".format(package_target.label))

    info = package_target[NpmPackageInfo]
    if info.package != ctx.attr.expected_package:
        fail("NpmPackageInfo package is {}, expected {}".format(
            info.package,
            ctx.attr.expected_package,
        ))
    if info.version != ctx.attr.expected_version:
        fail("NpmPackageInfo version is {}, expected {}".format(
            info.version,
            ctx.attr.expected_version,
        ))

    package_tree = info.src
    if not package_tree.is_directory:
        fail("NpmPackageInfo src must be a tree artifact: {}".format(package_tree.path))
    if package_tree.owner != package_target.label:
        fail("package tree owner is {}, expected {}".format(
            package_tree.owner,
            package_target.label,
        ))

    default_files = package_target[DefaultInfo].files.to_list()
    if default_files != [package_tree]:
        fail("package DefaultInfo must contain only its NpmPackageInfo tree artifact")

    compiled_info = compiled_target[JsInfo]
    compiled_files = depset(transitive = [
        compiled_info.sources,
        compiled_info.types,
    ]).to_list()
    if not compiled_files:
        fail("compiled package target has no output files")

    compiled_paths = []
    for output in compiled_files:
        if output.is_directory:
            fail("compiled output must be a file, got tree artifact {}".format(output.path))
        if output.owner != compiled_target.label:
            fail("compiled output {} is owned by {}, expected {}".format(
                output.path,
                output.owner,
                compiled_target.label,
            ))
        if not output.short_path.startswith("dist/"):
            fail("compiled output is outside dist/: {}".format(output.short_path))
        compiled_paths.append(output.short_path)

    dependencies = {}
    dependency_metadata = []
    for dependency in info.npm_package_store_infos.to_list():
        if dependency.package in dependencies:
            fail("duplicate packaged dependency record for {}".format(dependency.package))
        if not dependency.package_store_directory:
            fail("packaged dependency {} has no store tree".format(dependency.package))
        if not dependency.package_store_directory.is_directory:
            fail("packaged dependency {} store is not a tree artifact".format(dependency.package))

        dependency_files = dependency.files.to_list()
        if not dependency_files:
            fail("packaged dependency {} has no store files".format(dependency.package))

        dependencies[dependency.package] = dependency.version
        dependency_metadata.append({
            "files": sorted([file.short_path for file in dependency_files]),
            "package": dependency.package,
            "store_owner": str(dependency.package_store_directory.owner),
            "store_path": dependency.package_store_directory.short_path,
            "store_tree": dependency.package_store_directory.is_directory,
            "version": dependency.version,
        })

    if dependencies != ctx.attr.expected_dependencies:
        fail("packaged dependencies are {}, expected {}".format(
            dependencies,
            ctx.attr.expected_dependencies,
        ))

    metadata = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.write(
        metadata,
        json.encode({
            "compiled_files": sorted(compiled_paths),
            "compiled_owner": str(compiled_target.label),
            "dependencies": dependency_metadata,
            "package": info.package,
            "package_default_files": [file.short_path for file in default_files],
            "package_owner": str(package_tree.owner),
            "package_target": str(package_target.label),
            "package_tree": package_tree.short_path,
            "package_tree_is_directory": package_tree.is_directory,
            "version": info.version,
        }) + "\n",
    )

    return [DefaultInfo(files = depset([metadata]))]

producer_package_metadata = rule(
    implementation = _producer_package_metadata_impl,
    attrs = {
        "compiled": attr.label(
            mandatory = True,
            providers = [JsInfo],
        ),
        "expected_dependencies": attr.string_dict(mandatory = True),
        "expected_package": attr.string(mandatory = True),
        "expected_version": attr.string(mandatory = True),
        "package": attr.label(
            mandatory = True,
            providers = [NpmPackageInfo],
        ),
    },
)
