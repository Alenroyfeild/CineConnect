import Foundation

/// Owns search-query normalization and the "is there anything to search
/// for" decision - the one thing worth a use case here, since it's real
/// application-level policy, not just a forwarding call.
struct SearchMoviesUseCase {
    private let repository: MovieRepository

    init(repository: MovieRepository) {
        self.repository = repository
    }

    /// Returns `nil` - not an empty array, not a thrown error - when
    /// `query` has nothing to search for after trimming. That's a
    /// distinct outcome from "searched and found zero results" or
    /// "search failed," and callers should treat it as such.
    func callAsFunction(query: String) async throws -> [Movie]? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return try await repository.searchMovies(query: normalized)
    }
}
