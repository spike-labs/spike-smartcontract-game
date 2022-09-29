const fs = require('fs');
const jsonReader = function(filePath, cb) {
    fs.readFile(filePath, (err, fileData) => {
        if (err) {
            return cb && cb(err);
        }
        try {
            const object = JSON.parse(fileData);
            return cb && cb(null, object);
        } catch (err) {
            return cb && cb(err);
        }
    })
}

const jsonWriter = function(filePath, jsonData) {
    const jsonString = JSON.stringify(jsonData, null, 2);
    fs.writeFileSync(filePath, jsonString, err => {
        if (err) {
            console.log('Error writing file', err)
        } else {
            console.log('Successfully wrote file')
        }
      })
}

exports.jsonReader = jsonReader
exports.jsonWriter = jsonWriter