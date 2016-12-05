//
//  PostgreStORM.swift
//  PostgresSTORM
//
//  Created by Jonathan Guthrie on 2016-10-03.
//
//

import StORM
import PostgreSQL
import PerfectLogger

public struct PostgresConnector {

	public static var host: String		= ""
	public static var username: String	= ""
	public static var password: String	= ""
	public static var database: String	= ""
	public static var port: Int			= 0

	private init(){}

}

open class PostgresStORM: StORM, StORMProtocol {
	private var connection = PostgresConnect()


	open func table() -> String {
		return "unset"
	}

	override public init() {
		super.init()
	}

	private func printDebug(_ statement: String, _ params: [String]) {
		if StORMdebug { print("StORM Debug: \(statement) : \(params.joined(separator: ", "))") }
	}

	// Internal function which executes statements, with parameter binding
	// Returns raw result
	@discardableResult
	func exec(_ statement: String, params: [String]) throws -> PGResult {
		let thisConnection = PostgresConnect(
			host:		PostgresConnector.host,
			username:	PostgresConnector.username,
			password:	PostgresConnector.password,
			database:	PostgresConnector.database,
			port:		PostgresConnector.port
		)

		thisConnection.open()
		thisConnection.statement = statement

		printDebug(statement, params)
		let result = thisConnection.server.exec(statement: statement, params: params)

		// set exec message
		errorMsg = thisConnection.server.errorMessage().trimmingCharacters(in: .whitespacesAndNewlines)
		if StORMdebug { LogFile.info("Error msg: \(errorMsg)", logFile: "./StORMlog.txt") }
		if isError() {
			thisConnection.server.close()
			throw StORMError.error(errorMsg)
		}
		thisConnection.server.close()
		return result
	}

	// Internal function which executes statements, with parameter binding
	// Returns a processed row set
	@discardableResult
	func execRows(_ statement: String, params: [String]) throws -> [StORMRow] {
		let thisConnection = PostgresConnect(
			host:		PostgresConnector.host,
			username:	PostgresConnector.username,
			password:	PostgresConnector.password,
			database:	PostgresConnector.database,
			port:		PostgresConnector.port
		)

		thisConnection.open()
		thisConnection.statement = statement

		printDebug(statement, params)
		let result = thisConnection.server.exec(statement: statement, params: params)

		// set exec message
		errorMsg = thisConnection.server.errorMessage().trimmingCharacters(in: .whitespacesAndNewlines)
		if StORMdebug { LogFile.info("Error msg: \(errorMsg)", logFile: "./StORMlog.txt") }
		if isError() {
			thisConnection.server.close()
			throw StORMError.error(errorMsg)
		}

		let resultRows = parseRows(result)
		//		result.clear()
		thisConnection.server.close()
		return resultRows
	}


	func isError() -> Bool {
		if errorMsg.contains(string: "ERROR") {
			print(errorMsg)
			return true
		}
		return false
	}

	open func to(_ this: StORMRow) {
		//		id				= this.data["id"] as! Int
		//		firstname		= this.data["firstname"] as! String
		//		lastname		= this.data["lastname"] as! String
		//		email			= this.data["email"] as! String
	}

	open func makeRow() {
		guard self.results.rows.count > 0 else {
			return
		}
		self.to(self.results.rows[0])
	}

	@discardableResult
	open func save() throws {
		do {
			if keyIsEmpty() {
				try insert(asData(1))
			} else {
				let (idname, idval) = firstAsKey()
				try update(data: asData(1), idName: idname, idValue: idval)
			}
		} catch {
			throw StORMError.error(error.localizedDescription)
		}
	}
	@discardableResult
	open func save(set: (_ id: Any)->Void) throws {
		do {
			if keyIsEmpty() {
				let setId = try insert(asData(1))
				set(setId)
			} else {
				let (idname, idval) = firstAsKey()
				try update(data: asData(1), idName: idname, idValue: idval)
			}
		} catch {
			throw StORMError.error(error.localizedDescription)
		}
	}

	@discardableResult
	override open func create() throws {
		do {
			try insert(asData())
		} catch {
			throw StORMError.error(error.localizedDescription)
		}
	}

	/// Table Creation (alias for setup)
	@discardableResult
	open func setupTable(_ str: String = "") throws {
		try setup(str)
	}

	/// Table Creation
	@discardableResult
	open func setup(_ str: String = "") throws {
		var createStatement = str
		if str.characters.count == 0 {
			var opt = [String]()
			var keyName = ""
			for child in Mirror(reflecting: self).children {
				guard let key = child.label else {
					continue
				}
				var verbage = ""
				if !key.hasPrefix("internal_") {
					verbage = "\(key) "
					if child.value is Int && opt.count == 0 {
						verbage += "serial"
					} else if child.value is Int {
						verbage += "int8"
					} else if child.value is Bool {
						verbage += "bool"
					} else if child.value is [String:Any] {
						verbage += "jsonb"
					} else if child.value is Double {
						verbage += "float8"
					} else if child.value is UInt || child.value is UInt8 || child.value is UInt16 || child.value is UInt32 || child.value is UInt64 {
						verbage += "bytea"
					} else {
						verbage += "text"
					}
					if opt.count == 0 {
						verbage += " NOT NULL"
						keyName = key
					}
					opt.append(verbage)
				}
			}
			let keyComponent = ", CONSTRAINT \"\(table())_key\" PRIMARY KEY (\"\(keyName)\") NOT DEFERRABLE INITIALLY IMMEDIATE"

			createStatement = "CREATE TABLE IF NOT EXISTS \(table()) (\(opt.joined(separator: ", "))\(keyComponent));"

		}
		do {
			try sql(createStatement, params: [])
		} catch {
			print(error)
			throw StORMError.error(String(describing: error))
		}
	}
	
}


