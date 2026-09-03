cmake_minimum_required(VERSION 3.25)
project(ikigai-blobs LANGUAGES CXX)

# The blob renderer vendored from caelestia-shell (see scripts/vendor-blobs.sh), exposed
# to the shell as the `Ikigai.Blobs` QML module. Sources are untouched; the shaders'
# resource path (/shaders/*.qsb) is what blobmaterial.cpp expects.
find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick ShaderTools)
qt_standard_project_setup(REQUIRES 6.9)
set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")

qt_add_qml_module(ikigai-blobs
    URI Ikigai.Blobs
    PLUGIN_TARGET ikigai-blobs
    SOURCES
        blobs/blobgroup.cpp blobs/blobgroup.hpp
        blobs/blobshape.cpp blobs/blobshape.hpp
        blobs/blobrect.cpp blobs/blobrect.hpp
        blobs/blobinvertedrect.cpp blobs/blobinvertedrect.hpp
        blobs/blobmaterial.cpp blobs/blobmaterial.hpp
)
target_include_directories(ikigai-blobs PRIVATE blobs)
target_link_libraries(ikigai-blobs PRIVATE Qt::Quick)

qt_add_shaders(ikigai-blobs "blob_shaders"
    BATCHABLE OPTIMIZED NOHLSL NOMSL
    GLSL "300es,330"
    PREFIX "/"
    BASE blobs
    FILES
        blobs/shaders/blob.frag
        blobs/shaders/blob.vert
)

qt_query_qml_module(ikigai-blobs QMLDIR module_qmldir TYPEINFO module_typeinfo)
set(module_dir "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Ikigai/Blobs")
install(TARGETS ikigai-blobs LIBRARY DESTINATION "${module_dir}")
install(FILES "${module_qmldir}" "${module_typeinfo}" DESTINATION "${module_dir}")
