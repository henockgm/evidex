# Where the local embeddings model lives. The Docker image bakes it into
# EVIDEX_MODEL_DIR (and sets INFORMERS_OFFLINE=1, so it's never downloaded at
# runtime); locally the gem's default ~/.cache/informers is used.
Informers.cache_dir = ENV["EVIDEX_MODEL_DIR"] if ENV["EVIDEX_MODEL_DIR"].present?
