#!/bin/bash

source ${SDK_SRC_ROOT_DIR}/.config
source ${SDK_TOOLS_DIR}/gen_image_func.sh

repo_info_file=${SDK_BUILD_DIR}/repo_info

gen_repo_info()
{
	pushd ${SDK_SRC_ROOT_DIR} > /dev/null

	input_data=`repo info`
	temp_file=${SDK_BUILD_DIR}/repo_info.tmp

	> $temp_file
	# Process the input data
	echo "$input_data" | awk '
	/^Project:/ {project=$2}
	/Current revision:/ {
		revision=$3
		# Extract last segment of the project path
		split(project, parts, "/")
		last_segment=parts[length(parts)]
		print last_segment "=" revision >> "'$temp_file'"
	}'

	sed 's/-/_/g' $temp_file > $repo_info_file

	popd > /dev/null
}

gen_image()
{
	local config="$1";
	local image="$2";

	GENIMAGE_TMP="genimage.tmp"; rm -rf "${GENIMAGE_TMP}";
	${TOOL_GENIMAGE} --rootpath "${SDK_BUILD_IMAGES_DIR}" --tmppath "${GENIMAGE_TMP}" --inputpath "${SDK_BUILD_IMAGES_DIR}" --outputpath "${SDK_BUILD_DIR}" --config "${config}"

	rm -rf "${GENIMAGE_TMP}"
	gzip -k -f ${SDK_BUILD_DIR}/${image}
	chmod a+rw ${SDK_BUILD_DIR}/${image} ${SDK_BUILD_DIR}/${image}.gz;
	# gz_file_add_ver ${image}.gz
}

parse_canmv_revision() {
    pushd "${SDK_CANMV_SRC_DIR}" > /dev/null

    # Get the revision and store it in a variable
    revision=$(git describe --long --tag --dirty --always)

    popd > /dev/null

    # Print the revision to be captured by the caller
    echo "$revision"
}

gen_repo_info
cp -f $repo_info_file ${SDK_BUILD_IMAGES_DIR}/sdcard/revision.txt

# Read the file line by line
while IFS='=' read -r key value; do
  # Skip empty lines or lines that don't contain '='
  if [ -z "$key" ] || [ -z "$value" ]; then
    continue
  fi

  # Assign the value to the variable
  eval "$key=\"$value\""

  # Print the variable to verify
  echo "Variable '$key' has value '${!key}'"
done < "$repo_info_file"

# generate image name
if [ "$CONFIG_SDK_ENABLE_CANMV" = "y" ]; then
    canmv_revision=$(parse_canmv_revision)
    image_name="canmv_k230_${CONFIG_BOARD}_${canmv_revision}.img"
else
    image_name="k230_rt_only_${CONFIG_BOARD}_${superproject_k230_rtsmart}.img"
fi

gen_image ${SDK_BOARD_DIR}/${CONFIG_BOARD_GEN_IMAGE_CFG_FILE} sysimage-sdcard.img;

# rename image
if [ $IS_CI -eq 1 ]; then
	pushd ${SDK_BUILD_DIR} > /dev/null
	mv sysimage-sdcard.img $image_name
	mv sysimage-sdcard.img.gz $image_name.gz
	popd > /dev/null
fi
