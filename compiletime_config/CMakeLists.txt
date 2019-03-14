ADD_CUSTOM_TARGET (_generate_code_revision
                    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_BINARY_DIR}/code_revision.cmake
                    BYPRODUCTS ${CODE_REVISION_SOURCE_FILE}
                    )


##PORT-PROTOCOLS CLASSIFICATION
#INCLUDE (ExternalProject)
#ExternalProject_Add (
#    PORTPROTO_GENERATOR_BUILD
#    DOWNLOAD_COMMAND ""
#    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/protogen
#    #This requires cmake > v3.2
#    #BUILD_BYPRODUCTS ${CMAKE_CURRENT_BINARY_DIR}/protogen/portproto_generator
#    INSTALL_COMMAND ""
#    BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/protogen
#    CMAKE_ARGS -DGTPANALYZER_SOURCE_DIR=${CMAKE_SOURCE_DIR} -DCMAKE_CXX_FLAGS=${GNUCXX_VERSION_SPECIFIC_FLAGS}
#    )
#
##The following forces a reconfiguration evertytime, so that if the sources of the external project change,
##it gets rebuilt
#ExternalProject_Add_Step (
#    PORTPROTO_GENERATOR_BUILD
#    forceconfigure
#    #COMMAND ${CMAKE_COMMAND} -E echo "******** Ensure portproto_generator is up to date ********"
#    DEPENDEES update
#    DEPENDERS configure
#    ALWAYS 1
#    )
#ExternalProject_Get_Property(PORTPROTO_GENERATOR_BUILD BINARY_DIR)
#
#ADD_EXECUTABLE(portproto_generator IMPORTED)
#SET_TARGET_PROPERTIES (portproto_generator PROPERTIES IMPORTED_LOCATION ${BINARY_DIR}/portproto_generator)
#
#SET (PORTPROTOGEN_OUTPUT_FILE "${GENERATED_CODE_FOLDER}/portproto_classifier.hpp")
#
##NOTE: Using the executable target "portproto_generator" as the COMMAND, only a target-level dependency and NOT a file-level dependency
##will be added, so that the executable target will be built before any targets using this custom command's OUTPUT
##__BUT__, not being a file-level dependency, the custom command won't be re-run whenever the executable portproto_generator is recompiled.
##To enforce this desired file-level dependency, a "DEPENDS portproto_generator" specification has been added
#ADD_CUSTOM_COMMAND (
#    OUTPUT ${PORTPROTOGEN_OUTPUT_FILE}
#    COMMAND portproto_generator ${CMAKE_CURRENT_SOURCE_DIR}/protogen/conf/port_protocols-${CUSTOM_PORTPROTO_CLASSIFIER}.txt > ${PORTPROTOGEN_OUTPUT_FILE}
#    COMMENT "Generating ${PORTPROTOGEN_OUTPUT_FILE} for ${CUSTOM_PORTPROTO_CLASSIFIER}"
#    DEPENDS portproto_generator ${CMAKE_CURRENT_SOURCE_DIR}/protogen/conf/port_protocols-${CUSTOM_PORTPROTO_CLASSIFIER}.txt
#    )
#
#ADD_CUSTOM_TARGET (_generate_portproto_classifier
#                ALL
#                DEPENDS ${PORTPROTOGEN_OUTPUT_FILE} PORTPROTO_GENERATOR_BUILD
#                )
